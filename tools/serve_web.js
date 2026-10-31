// Servidor estático mínimo para testar a exportação Web: node tools/serve_web.js [porta]
const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..", "web");
const port = Number(process.argv[2] || 8060);
const types = {
	".html": "text/html", ".js": "application/javascript", ".wasm": "application/wasm",
	".pck": "application/octet-stream", ".png": "image/png",
};

http.createServer((req, res) => {
	const url = decodeURIComponent(req.url.split("?")[0]);
	const file = path.join(root, url === "/" ? "index.html" : url);
	if (!file.startsWith(root)) {
		res.writeHead(403);
		return res.end();
	}
	fs.readFile(file, (err, data) => {
		if (err) {
			res.writeHead(404);
			return res.end("não encontrado");
		}
		res.writeHead(200, {
			"Content-Type": types[path.extname(file)] || "application/octet-stream",
			"Cross-Origin-Opener-Policy": "same-origin",
			"Cross-Origin-Embedder-Policy": "require-corp",
		});
		res.end(data);
	});
}).listen(port, () => console.log("Star-RTS web em http://localhost:" + port));
