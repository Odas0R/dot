import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { MAX_MESSAGE_BYTES, MAX_IMAGE_BYTES, MAX_IMAGES, PROTOCOL_VERSION } from "../protocol.js";

const source = readFileSync(new URL("../plugin/code.js", import.meta.url), "utf8");
function sandbox() {
	const context = vm.createContext({ console, setTimeout, clearTimeout });
	vm.runInContext(`
		var messages = [], listeners = new Map(), undos = 0;
		var text = {id:'1:2',type:'TEXT',name:'Title',fills:[{type:'SOLID'}],opacity:1};
		var frame = {id:'1:1',type:'FRAME',name:'Card',children:[text],width:100,height:100,resize(w,h){this.width=w;this.height=h},exportAsync:async()=>new Uint8Array([1,2,3])};
		var page = {id:'0:1',type:'PAGE',name:'Page',children:[frame]};
		var root = {id:'0:0',type:'DOCUMENT',name:'Test',children:[page]};
		text.parent=frame;frame.parent=page;page.parent=root;
		var release; var waiting=new Promise(resolve=>release=resolve);
		var figma = {
			root,currentPage:page,editorType:'figma',showUI(){},
			ui:{postMessage(message){messages.push(message)}},
			on(name,fn){listeners.set(name,fn)},off(name,fn){if(listeners.get(name)===fn)listeners.delete(name)},
			listenerCount(name){return listeners.has(name)?1:0},
			viewport:{scrollAndZoomIntoView(nodes){if(nodes[0]!==frame)throw Error('non-native node');}},
			acceptOptions(options){if(options.node!==frame)throw Error('non-native nested node')},
			clientStorage:{async getAsync(){return ''},async setAsync(){}},
			commitUndo(){undos++},wait(){return waiting},
			getNodeByIdAsync:async id=>id==='1:2'?text:null
		};
		var __html__ = '';
	`, context);
	vm.runInContext(source, context, { filename: "plugin/code.js" });
	let sequence = 0;
	async function execute(code, options = {}) {
		const id = `test-${sequence++}`;
		await context.figma.ui.onmessage({ type: "execute", id, code, deadline: Date.now() + 5000, ...options });
		return context.messages.find(m => m.id === id && ["result", "error"].includes(m.type));
	}
	return { context, execute };
}

test("wire constants match the broker", () => {
	const context = sandbox().context;
	for (const [name, expected] of Object.entries({ MAX_MESSAGE_BYTES, MAX_IMAGE_BYTES, MAX_IMAGES, PROTOCOL_VERSION })) assert.equal(vm.runInContext(name, context), expected);
});

test("selector matching supports wildcard paths, IDs, pseudo-classes and combinators", async () => {
	const { execute } = sandbox();
	for (const selector of ['[fills.*.type=SOLID]', '[fills.0.type=SOLID]', '#1-2:first-child', '#1:2:first-child', ':not([name=")"]):is(TEXT)', 'FRAME > TEXT', 'FRAME TEXT', 'TEXT:nth-child(1)', 'TEXT[name^=Tit]', 'RECTANGLE, TEXT']) {
		const response = await execute(`return figma.currentPage.query(${JSON.stringify(selector)}).values(['id']);`);
		assert.equal(response.type, "result", response.message);
		assert.deepEqual(JSON.parse(response.text), [{ id: "1:2" }], selector);
	}
});

test("malformed selectors fail before mutations even on empty or non-matching subtrees", async () => {
	const { execute, context } = sandbox();
	for (const selector of ['FRAME >', '> FRAME', 'FRAME >> TEXT', 'FRAME,', ',TEXT', 'FRAME,,TEXT', 'TEXT[', 'FRAME:bogus', '[name!=x]', ':nth-child()', ':first-child(2)', ':is()', 'TEXT > :bogus']) {
		const response = await execute(`figma.currentPage.query(${JSON.stringify(selector)}).set({opacity:0});`);
		assert.equal(response.type, "error", selector);
		assert.equal(context.text.opacity, 1);
	}
	context.page.children = [];
	assert.equal((await execute('figma.currentPage.query("FRAME >").set({opacity:0});')).type, "error");
});

test("attribute strings respect escapes and quoted parentheses", async () => {
	const { execute, context } = sandbox();
	context.text.name = ') "title" \\';
	const selector = `TEXT[name=${JSON.stringify(context.text.name)}]`;
	assert.equal(JSON.parse((await execute(`return figma.currentPage.query(${JSON.stringify(selector)}).length;`)).text), 1);
});

test("nodes and shared references serialize without data loss or false cycles", async () => {
	const { execute } = sandbox();
	assert.deepEqual(JSON.parse((await execute('return figma.currentPage.children[0];')).text), { id: "1:1", type: "FRAME", name: "Card" });
	assert.deepEqual(JSON.parse((await execute('const x={a:1};return [x,x];')).text), [{ a: 1 }, { a: 1 }]);
	assert.deepEqual(JSON.parse((await execute('const x={};x.self=x;return x;')).text), { self: "[Circular]" });
});

test("structured output is minified while literal strings preserve formatting", async () => {
	const { execute } = sandbox();
	const result = await execute('return {rootId:"1:1",refs:{header:"1:2"},createdNodeIds:["1:1","1:2"],issues:[]};');
	assert.equal(result.text, '{"rootId":"1:1","refs":{"header":"1:2"},"createdNodeIds":["1:1","1:2"],"issues":[]}');
	const literal = '  line one\n\n  line two';
	assert.equal((await execute(`return ${JSON.stringify(literal)};`)).text, literal);
});

test("a preflighted stage can update more than ten repeated elements in one call", async () => {
	const { execute, context } = sandbox();
	context.frame.children = Array.from({ length: 40 }, (_, i) => ({ id: `3:${i}`, type: "RECTANGLE", name: "Card", opacity: 1, parent: context.frame }));
	const result = await execute(`
		const cards = figma.currentPage.query('RECTANGLE[name=Card]');
		if (cards.length !== 40) return {issues:['Unexpected card count']};
		cards.set({opacity:0.5});
		return {rootId:figma.currentPage.children[0].id,mutatedNodeIds:cards.values(['id']).map(n=>n.id),issues:[]};
	`);
	assert.equal(result.type, "result", result.message);
	assert.equal(JSON.parse(result.text).mutatedNodeIds.length, 40);
	assert.ok(context.frame.children.every(node => node.opacity === 0.5));
	assert.equal(context.undos, 1);
});

test("callback identities, nested APIs, nested node arguments and proxy enumeration work", async () => {
	const { execute } = sandbox();
	const response = await execute(`
		function cb(){};
		figma.on('selectionchange',cb);figma.off('selectionchange',cb);
		figma.viewport.scrollAndZoomIntoView([figma.currentPage.children[0]]);
		figma.acceptOptions({node:figma.currentPage.children[0]});
		const node=await figma.getNodeByIdAsync('1:2');
		return {listeners:figma.listenerCount('selectionchange'),paint:{...node.fills[0]}};
	`);
	assert.equal(response.type, "result", response.message);
	assert.deepEqual(JSON.parse(response.text), { listeners: 0, paint: { type: "SOLID" } });
});

test("plugin refuses overlapping work, reports busy across transports and guards late mutations", async () => {
	const { execute, context } = sandbox();
	const first = execute('await figma.wait();figma.currentPage.children[0].name="late mutation";return 1;');
	assert.equal((await execute('return 2;')).type, "error");
	await context.figma.ui.onmessage({ type: "transport-lost" });
	assert.ok(context.messages.filter(m => m.type === "target").at(-1).busyId);
	context.release();
	assert.equal((await first).type, "error");
	assert.equal(context.frame.name, "Card");
	assert.equal(context.messages.filter(m => m.type === "target").at(-1).busyId, null);
	assert.equal((await execute('return 3;')).type, "result");
});

test("deadline preflight, partial failure and per-call undo boundaries", async () => {
	const { execute, context } = sandbox();
	assert.equal((await execute('figma.currentPage.name="wrong"', { deadline: Date.now() - 1 })).type, "error");
	assert.equal(context.page.name, "Page");
	assert.equal((await execute('figma.currentPage.name="changed";throw Error("fail");')).type, "error");
	assert.equal(context.page.name, "changed");
	assert.equal(context.undos, 1);
});

test("oversized output and screenshots return useful errors without dropping transport", async () => {
	const { execute, context } = sandbox();
	assert.match((await execute('return "x".repeat(17*1024*1024);')).message, /16 MiB/);
	const shots = await execute('for(let i=0;i<11;i++)await figma.currentPage.children[0].screenshot();');
	assert.match(shots.message, /Screenshot budget/);
	context.frame.exportAsync = async () => new Uint8Array(7 * 1024 * 1024);
	assert.match((await execute('await figma.currentPage.children[0].screenshot();')).message, /Screenshot budget/);
	assert.equal((await execute('return 1;')).type, "result");
});

test("script event handlers are cleaned up after completion", async () => {
	const { execute, context } = sandbox();
	await execute('figma.on("selectionchange",()=>{});return 1;');
	assert.equal(context.listeners.has("selectionchange"), false);
});
