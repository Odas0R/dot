// Self-contained factory: all proxy caches and subscriptions belong to one execution.
export function createHelpers(figma, run, limits, selectors) {
	const { MAX_MESSAGE_BYTES, MAX_IMAGE_BYTES, MAX_IMAGES } = limits;
	const { compileSelector, readPathValues, descendants } = selectors;
	const NODE_TYPES = new Set([
		"DOCUMENT",
		"PAGE",
		"SLICE",
		"FRAME",
		"GROUP",
		"SECTION",
		"COMPONENT_SET",
		"COMPONENT",
		"INSTANCE",
		"SLOT",
		"BOOLEAN_OPERATION",
		"VECTOR",
		"STAR",
		"LINE",
		"ELLIPSE",
		"POLYGON",
		"RECTANGLE",
		"TEXT",
		"TEXT_PATH",
		"STAMP",
		"HIGHLIGHT",
		"WASHI_TAPE",
		"SHAPE_WITH_TEXT",
		"CODE_BLOCK",
		"CONNECTOR",
		"WIDGET",
		"EMBED",
		"LINK_UNFURL",
		"MEDIA",
		"STICKY",
		"TABLE",
		"TABLE_CELL",
		"SLIDE",
		"SLIDE_ROW",
		"SLIDE_GRID",
		"INTERACTIVE_SLIDE_ELEMENT",
		"TRANSFORM_GROUP",
	]);
	const isRecord = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
	function isNode(value) {
		if (!isRecord(value)) return false;
		try {
			return typeof value.id === "string" && NODE_TYPES.has(value.type);
		} catch {
			return false;
		}
	}
	function serialize(value) {
		if (value === undefined) return "undefined";
		if (typeof value === "string") return value;
		const ancestors = [];
		return (
			JSON.stringify(value, function (_key, item) {
				if (typeof item === "bigint") return `${item}n`;
				if (isNode(item)) return { id: item.id, type: item.type, name: item.name };
				if (typeof item !== "object" || item === null) return item;
				while (ancestors.length && ancestors[ancestors.length - 1] !== this) ancestors.pop();
				if (ancestors.includes(item)) return "[Circular]";
				ancestors.push(item);
				return item;
			}) ?? "undefined"
		);
	}
	function utf8Length(text) {
		let bytes = 0;
		for (const character of text) {
			const point = character.codePointAt(0);
			bytes += point <= 0x7f ? 1 : point <= 0x7ff ? 2 : point <= 0xffff ? 3 : 4;
		}
		return bytes;
	}
	function bytesToBase64(bytes) {
		const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
		const chunks = [];
		let output = "";
		for (let i = 0; i < bytes.length; i += 3) {
			const value = (bytes[i] << 16) | ((bytes[i + 1] || 0) << 8) | (bytes[i + 2] || 0);
			output +=
				alphabet[(value >> 18) & 63] +
				alphabet[(value >> 12) & 63] +
				(i + 1 < bytes.length ? alphabet[(value >> 6) & 63] : "=") +
				(i + 2 < bytes.length ? alphabet[value & 63] : "=");
			if (output.length >= 8192) {
				chunks.push(output);
				output = "";
			}
		}
		chunks.push(output);
		return chunks.join("");
	}
	const screenshots = [];
	let imageBytes = 0;
	const nativeToProxy = new WeakMap();
	const proxyToNative = new WeakMap();
	const callbacks = new WeakMap();
	const subscriptions = [];
	const pending = new Set();
	function track(promise) {
		const settled = promise.then(
			() => {},
			() => {},
		);
		pending.add(settled);
		void settled.then(() => pending.delete(settled));
		return promise;
	}
	function guard() {
		if (run.finished || run.cancelled || Date.now() >= run.deadline)
			throw new Error("Execution cancelled or expired. Changes may remain; inspect before retrying.");
	}
	function unwrap(value, seen = new WeakMap()) {
		if (proxyToNative.has(value)) return proxyToNative.get(value);
		if (typeof value === "function") {
			if (!callbacks.has(value))
				callbacks.set(value, function (...args) {
					guard();
					return unwrap(value.apply(this, args.map(wrap)));
				});
			return callbacks.get(value);
		}
		if (!value || typeof value !== "object" || ArrayBuffer.isView(value)) return value;
		if (seen.has(value)) return seen.get(value);
		if (
			Array.isArray(value) ||
			Object.getPrototypeOf(value) === Object.prototype ||
			Object.getPrototypeOf(value) === null
		) {
			const copy = Array.isArray(value) ? [] : {};
			seen.set(value, copy);
			for (const key of Object.keys(value))
				Object.defineProperty(copy, key, {
					value: unwrap(value[key], seen),
					enumerable: true,
					writable: true,
					configurable: true,
				});
			return copy;
		}
		return value;
	}
	function wrap(value) {
		if (value instanceof Promise) return track(value.then(wrap));
		if (Array.isArray(value)) return value.map(wrap);
		if (!value || typeof value !== "object" || ArrayBuffer.isView(value) || value instanceof ArrayBuffer) return value;
		return wrapObject(value);
	}
	function setNodeProperties(node, properties) {
		guard();
		if (!isRecord(properties)) throw new Error("node.set() requires a properties object");
		const props = { ...properties };
		if (Object.prototype.hasOwnProperty.call(props, "layoutMode")) {
			node.layoutMode = props.layoutMode;
			delete props.layoutMode;
		}
		if (Object.prototype.hasOwnProperty.call(props, "width") || Object.prototype.hasOwnProperty.call(props, "height")) {
			if (typeof node.resize !== "function") throw new Error(`${node.type} does not support width or height`);
			node.resize(
				props.width === undefined ? node.width : props.width,
				props.height === undefined ? node.height : props.height,
			);
			delete props.width;
			delete props.height;
		}
		for (const [key, value] of Object.entries(props)) node[key] = unwrap(value);
		return wrap(node);
	}
	function queryNodes(root, selector) {
		guard();
		const match = compileSelector(selector);
		return descendants(root).filter((node) => match(node, root));
	}
	function createQueryResult(nativeNodes) {
		const nodes = [...new Map(nativeNodes.map((node) => [node.id, node])).values()];
		const result = {
			get length() {
				return nodes.length;
			},
			first() {
				return nodes.length ? wrap(nodes[0]) : null;
			},
			last() {
				return nodes.length ? wrap(nodes[nodes.length - 1]) : null;
			},
			toArray() {
				return nodes.map(wrap);
			},
			each(callback) {
				nodes.forEach((node, index) => callback(wrap(node), index));
				return result;
			},
			map(callback) {
				return nodes.map((node, index) => callback(wrap(node), index));
			},
			filter(callback) {
				return createQueryResult(nodes.filter((node, index) => callback(wrap(node), index)));
			},
			values(keys) {
				guard();
				return nodes.map((node) => Object.fromEntries(keys.map((key) => [key, wrap(readPathValues(node, key)[0])])));
			},
			set(properties) {
				nodes.forEach((node) => setNodeProperties(node, properties));
				return result;
			},
			query(selector) {
				compileSelector(selector);
				return createQueryResult(nodes.flatMap((node) => queryNodes(node, selector)));
			},
			[Symbol.iterator]() {
				return nodes.map(wrap)[Symbol.iterator]();
			},
		};
		return result;
	}
	async function screenshotNode(node, options = {}) {
		guard();
		if (typeof node.exportAsync !== "function") throw new Error(`${node.type} cannot be exported`);
		const scale =
			options.scale == null ? Math.min(0.5, 1024 / Math.max(node.width || 1, node.height || 1)) : options.scale;
		if (!Number.isFinite(scale) || scale <= 0) throw new Error("Screenshot scale must be greater than zero");
		const bytes = await node.exportAsync({
			format: "PNG",
			contentsOnly: options.contentsOnly !== false,
			constraint: { type: "SCALE", value: scale },
		});
		guard();
		const size = Math.ceil(bytes.length / 3) * 4;
		if (screenshots.length >= MAX_IMAGES || imageBytes + size > MAX_IMAGE_BYTES)
			throw new Error(
				"Screenshot budget exceeded (10 images / 8 MiB base64). Use fewer screenshots or a smaller scale; changes may remain.",
			);
		imageBytes += size;
		screenshots.push({
			data: bytesToBase64(bytes),
			mimeType: "image/png",
			name: `${String(node.name || node.type).slice(0, 1800)} (${Math.round(node.width || 0)}x${Math.round(node.height || 0)}).png`,
		});
	}
	function createAutoLayout(directionOrProperties = "HORIZONTAL", maybeProperties = {}) {
		guard();
		const direction = typeof directionOrProperties === "string" ? directionOrProperties : "HORIZONTAL";
		const properties = typeof directionOrProperties === "object" ? directionOrProperties : maybeProperties;
		if (!["HORIZONTAL", "VERTICAL"].includes(direction))
			throw new Error("Auto-layout direction must be HORIZONTAL or VERTICAL");
		const frame = figma.createFrame();
		frame.layoutMode = direction;
		frame.primaryAxisSizingMode = "AUTO";
		frame.counterAxisSizingMode = "AUTO";
		return setNodeProperties(frame, properties || {});
	}
	function wrapObject(object) {
		if (nativeToProxy.has(object)) return nativeToProxy.get(object);
		const node = isNode(object);
		const methodCache = new Map();
		const helpers = node
			? {
					set: (props) => setNodeProperties(object, props),
					query: (selector) => createQueryResult(queryNodes(object, selector)),
					matches: (selector) => compileSelector(selector)(object),
					screenshot: (options) => track(screenshotNode(object, options)),
					toJSON: () => ({ id: object.id, type: object.type, name: object.name }),
				}
			: object === figma
				? { createAutoLayout }
				: {};
		const proxy = new Proxy(
			{},
			{
				get(_facade, property) {
					guard();
					if (Object.prototype.hasOwnProperty.call(helpers, property)) return helpers[property];
					const value = Reflect.get(object, property, object);
					if (typeof value !== "function") return wrap(value);
					if (!methodCache.has(property))
						methodCache.set(property, (...args) => {
							guard();
							if (object === figma && ["closePlugin", "showUI", "triggerUndo"].includes(property))
								throw new Error(`${property} is reserved by Figpie; return data instead`);
							const nativeArgs = args.map((arg) => unwrap(arg));
							const result = value.apply(object, nativeArgs);
							if (
								["on", "once"].includes(property) &&
								typeof object.off === "function" &&
								typeof nativeArgs[1] === "function"
							)
								subscriptions.push([object, nativeArgs[0], nativeArgs[1]]);
							return wrap(result);
						});
					return methodCache.get(property);
				},
				set(_facade, property, value) {
					guard();
					return Reflect.set(object, property, unwrap(value), object);
				},
				has(_facade, property) {
					return Object.prototype.hasOwnProperty.call(helpers, property) || property in object;
				},
				ownKeys() {
					return Reflect.ownKeys(object);
				},
				getOwnPropertyDescriptor(_facade, property) {
					const descriptor = Reflect.getOwnPropertyDescriptor(object, property);
					return descriptor
						? {
								configurable: true,
								enumerable: descriptor.enumerable,
								writable: true,
								value: wrap(Reflect.get(object, property, object)),
							}
						: undefined;
				},
				getPrototypeOf() {
					return Reflect.getPrototypeOf(object);
				},
			},
		);
		nativeToProxy.set(object, proxy);
		proxyToNative.set(proxy, object);
		return proxy;
	}
	return {
		figma: wrapObject(figma),
		result(value) {
			guard();
			const response = { type: "result", id: run.id, text: serialize(value), images: screenshots };
			if (utf8Length(JSON.stringify(response)) > MAX_MESSAGE_BYTES - 4096)
				throw new Error("Result exceeds the 16 MiB budget. Return less data or fewer screenshots; changes may remain.");
			return response;
		},
		async dispose() {
			run.finished = true;
			for (const [object, event, callback] of subscriptions) {
				try {
					object.off(event, callback);
				} catch {}
			}
			// Promise.all can reject while another native operation is still running.
			// Drain those operations before releasing the persistent execution lock.
			while (pending.size) await Promise.all([...pending]);
			try {
				figma.commitUndo();
			} catch {}
		},
	};
}
