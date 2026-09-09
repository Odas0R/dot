import { startBroker } from "./broker.js";

try {
	const broker = await startBroker();
	if (broker) {
		for (const signal of ["SIGTERM", "SIGINT"]) {
			process.once(signal, () => void broker.close());
		}
	}
} catch (error) {
	console.error(`Figpie broker: ${error.message}`);
	process.exitCode = 1;
}
