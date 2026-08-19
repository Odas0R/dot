figma.showUI(__html__, { width: 300, height: 76, themeColors: true });

function serialize(value) {
	if (value === undefined) return "undefined";
	if (typeof value === "string") return value;
	try {
		const seen = new Set();
		return JSON.stringify(
			value,
			(_key, item) => {
				if (typeof item === "bigint") return `${item}n`;
				if (typeof item === "object" && item !== null) {
					if (seen.has(item)) return "[Circular]";
					seen.add(item);
				}
				return item;
			},
			2,
		);
	} catch (_error) {
		return String(value);
	}
}

function sendTarget() {
	figma.ui.postMessage({
		type: "target",
		fileName: figma.root.name,
		pageName: figma.currentPage.name,
		editorType: figma.editorType,
	});
}

figma.ui.onmessage = async (message) => {
	if (message.type === "ready") {
		sendTarget();
		return;
	}
	if (message.type !== "execute") return;

	try {
		const run = new Function(
			"figma",
			`return (async () => {\n${message.code}\n})();`,
		);
		const result = await run(figma);
		figma.ui.postMessage({
			type: "result",
			id: message.id,
			text: serialize(result),
		});
		sendTarget();
	} catch (error) {
		figma.ui.postMessage({
			type: "error",
			id: message.id,
			message: error instanceof Error ? error.message : String(error),
			stack: error instanceof Error ? error.stack : undefined,
		});
	}
};
