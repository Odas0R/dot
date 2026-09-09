import { EventEmitter } from "node:events";
import { MAX_MESSAGE_BYTES } from "./config.js";

// Length-prefixed JSON keeps large screenshots bounded without quadratic string
// concatenation. Filesystem permissions, not a token, protect this channel.
export class Channel extends EventEmitter {
	constructor(socket) {
		super();
		this.socket = socket;
		this.header = Buffer.alloc(4);
		this.offset = 0;
		this.body = null;
		socket.on("data", (chunk) => {
			try {
				this.receive(chunk);
			} catch (error) {
				socket.destroy(error);
			}
		});
		socket.on("error", (error) => {
			this.error = error;
		});
		socket.once("close", () => this.emit("close", this.error || new Error("Figpie broker disconnected")));
	}
	get closed() {
		return this.socket.destroyed;
	}
	receive(chunk) {
		while (chunk.length) {
			const destination = this.body || this.header;
			const length = Math.min(chunk.length, destination.length - this.offset);
			chunk.copy(destination, this.offset, 0, length);
			chunk = chunk.subarray(length);
			this.offset += length;
			if (this.offset !== destination.length) continue;
			this.offset = 0;
			if (!this.body) {
				const size = this.header.readUInt32BE();
				if (!size || size > MAX_MESSAGE_BYTES) throw new Error("Invalid Figpie message size");
				this.body = Buffer.allocUnsafe(size);
			} else {
				const message = JSON.parse(this.body.toString("utf8"));
				this.body = null;
				if (!message || typeof message !== "object" || Array.isArray(message) || typeof message.type !== "string")
					throw new Error("Invalid Figpie message");
				this.emit("message", message);
			}
		}
	}
	send(message) {
		const body = Buffer.from(JSON.stringify(message));
		if (body.length > MAX_MESSAGE_BYTES)
			throw new Error("Figpie message exceeds 16 MiB; return less data or fewer screenshots. Changes may remain.");
		if (this.closed) throw new Error("Figpie connection is closed");
		if (this.socket.writableLength + body.length > MAX_MESSAGE_BYTES * 2) throw new Error("Figpie send buffer is full");
		const header = Buffer.allocUnsafe(4);
		header.writeUInt32BE(body.length);
		this.socket.cork();
		this.socket.write(header);
		this.socket.write(body);
		this.socket.uncork();
	}
	close() {
		this.socket.destroy();
	}
}
