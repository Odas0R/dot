// Self-contained factory: injected into Figma without a bundler.
export function createSelectors() {
	// Parse the complete selector before evaluating any node, including empty subtrees.
	function compileSelector(selector) {
		if (typeof selector !== "string" || !selector.trim() || selector.length > 8192)
			throw new Error("Selector must be a non-empty string of at most 8192 characters");
		let index = 0;
		function error() {
			throw new Error(`Invalid selector near: ${selector.slice(index) || "<end>"}`);
		}
		function whitespace() {
			const start = index;
			while (/\s/.test(selector[index] || "") && index < selector.length) index++;
			return index > start;
		}
		function enclosed(open, close) {
			if (selector[index++] !== open) error();
			const start = index;
			let depth = 1;
			let quote;
			let escaped = false;
			for (; index < selector.length; index++) {
				const char = selector[index];
				if (escaped) {
					escaped = false;
					continue;
				}
				if (quote) {
					if (char === "\\") escaped = true;
					else if (char === quote) quote = undefined;
					continue;
				}
				if (char === '"' || char === "'") {
					quote = char;
					continue;
				}
				if (char === open) depth++;
				if (char === close) {
					depth--;
					if (depth === 0) {
						const content = selector.slice(start, index);
						index++;
						return content;
					}
				}
			}
			error();
		}
		function simple() {
			const predicates = [];
			const type = /^I?\d+[:-]\d+/.test(selector.slice(index))
				? null
				: selector.slice(index).match(/^(\*|[A-Za-z_][A-Za-z0-9_]*)/);
			if (type) {
				index += type[0].length;
				predicates.push((node) => type[0] === "*" || node.type.toUpperCase() === type[0].toUpperCase());
			}
			while (index < selector.length && !/[\s,>+~]/.test(selector[index])) {
				const char = selector[index];
				if (char === "#" || (!predicates.length && /[0-9I]/.test(char))) {
					if (char === "#") index++;
					// Figma IDs can include instance descendant segments separated by semicolons.
					const id = selector.slice(index).match(/^I?\d+[:-]\d+(?:;\d+[:-]\d+)*/);
					if (!id) error();
					index += id[0].length;
					predicates.push((node) => node.id === id[0].replace(/-/g, ":"));
				} else if (char === "[") {
					const expression = enclosed("[", "]");
					const match = expression.match(
						/^\s*([A-Za-z_$][\w$]*(?:\.(?:[\w$]+|\*))*)\s*(?:(\*=|\^=|\$=|=)\s*(.+?))?\s*$/,
					);
					if (!match) error();
					const [, path, operator, raw] = match;
					if (path.split(".").includes("mainComponent"))
						throw new Error(
							"mainComponent selectors are unavailable with dynamic pages; use getMainComponentAsync() on discovered instances",
						);
					const expected = operator ? parseLiteral(raw) : undefined;
					predicates.push((node) =>
						readPathValues(node, path).some((value) => {
							if (!operator) return value !== undefined;
							if (value === undefined) return false;
							const actual = value && typeof value === "object" && typeof value.id === "string" ? value.id : value;
							if (operator === "=") return actual === expected || String(actual) === String(expected);
							if (operator === "*=") return String(actual).includes(String(expected));
							if (operator === "^=") return String(actual).startsWith(String(expected));
							return String(actual).endsWith(String(expected));
						}),
					);
				} else if (char === ":") {
					index++;
					const match = selector.slice(index).match(/^[a-zA-Z-]+/);
					if (!match) error();
					const name = match[0].toLowerCase();
					index += match[0].length;
					const argument = selector[index] === "(" ? enclosed("(", ")") : undefined;
					if (["not", "is", "where"].includes(name)) {
						const nested = compileSelector(argument);
						predicates.push((node, boundary) => (name === "not" ? !nested(node, boundary) : nested(node, boundary)));
					} else if (["first-child", "last-child", "nth-child"].includes(name)) {
						if (name === "nth-child" ? !/^[1-9]\d*$/.test(argument || "") : argument !== undefined) error();
						predicates.push((node) => {
							const siblings = node.parent && "children" in node.parent ? node.parent.children : [];
							const position = siblings.indexOf(node);
							return (
								position >= 0 &&
								position ===
									(name === "first-child" ? 0 : name === "last-child" ? siblings.length - 1 : Number(argument) - 1)
							);
						});
					} else throw new Error(`Unsupported pseudo-class: ${name}`);
				} else error();
			}
			if (!predicates.length) error();
			return (node, boundary) => predicates.every((predicate) => predicate(node, boundary));
		}
		const groups = [];
		whitespace();
		while (index < selector.length) {
			const parts = [{ match: simple(), combinator: null }];
			while (index < selector.length) {
				const spaced = whitespace();
				if (index === selector.length || selector[index] === ",") break;
				let combinator = " ";
				if (/[>+~]/.test(selector[index])) {
					combinator = selector[index++];
					whitespace();
				} else if (!spaced) error();
				parts.push({ match: simple(), combinator });
			}
			groups.push(parts);
			if (index === selector.length) break;
			if (selector[index++] !== ",") error();
			whitespace();
			if (index === selector.length) error();
		}
		return (node, boundary) =>
			groups.some((parts) => {
				function at(candidate, part) {
					if (!candidate || !parts[part].match(candidate, boundary)) return false;
					if (!part) return true;
					if (candidate === boundary) return false;
					const combinator = parts[part].combinator;
					if (combinator === ">") return at(candidate.parent, part - 1);
					if (combinator === "+" || combinator === "~") {
						const siblings = candidate.parent && "children" in candidate.parent ? candidate.parent.children : [];
						const position = siblings.indexOf(candidate);
						return combinator === "+"
							? at(siblings[position - 1], part - 1)
							: siblings.slice(0, Math.max(0, position)).some((sibling) => at(sibling, part - 1));
					}
					for (let ancestor = candidate.parent; ancestor; ancestor = ancestor.parent) {
						if (at(ancestor, part - 1)) return true;
						if (ancestor === boundary) break;
					}
					return false;
				}
				return at(node, parts.length - 1);
			});
	}
	function parseLiteral(raw) {
		const value = raw.trim();
		if (value[0] === '"' || value[0] === "'") {
			if (value[value.length - 1] !== value[0]) throw new Error("Unclosed selector string");
			let decoded = "";
			for (let index = 1; index < value.length - 1; index++) {
				if (value[index] === value[0]) throw new Error("Unexpected quote in selector value");
				if (value[index] === "\\") {
					index++;
					if (index >= value.length - 1) throw new Error("Unclosed selector escape");
				}
				decoded += value[index];
			}
			return decoded;
		}
		if (/[\s\[\]'"()]/.test(value)) throw new Error("Quote selector attribute values containing spaces or punctuation");
		if (value === "true") return true;
		if (value === "false") return false;
		if (value === "null") return null;
		return value !== "" && Number.isFinite(Number(value)) ? Number(value) : value;
	}
	function readPathValues(value, path) {
		let values = [value];
		for (const segment of path.split(".")) {
			const next = [];
			for (const current of values) {
				if (current == null) continue;
				if (segment === "*") {
					if (Array.isArray(current)) next.push(...current);
					else if (typeof current === "object") next.push(...Object.values(current));
				} else next.push(current[segment]); // Getter errors must not silently hide matching nodes.
			}
			values = next;
		}
		return values;
	}
	function descendants(root) {
		const result = [];
		const stack = "children" in root ? [...root.children].reverse() : [];
		while (stack.length) {
			const node = stack.pop();
			result.push(node);
			if ("children" in node) for (let i = node.children.length - 1; i >= 0; i--) stack.push(node.children[i]);
		}
		return result;
	}
	return { compileSelector, readPathValues, descendants };
}
