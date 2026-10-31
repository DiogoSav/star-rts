// Carimba uma versão nos arquivos do jogo em web/index.html, para o navegador não usar a
// cópia antiga depois de uma nova publicação (o GitHub Pages manda guardar por 10 min).
// Uso, depois de exportar: node tools/cache_bust.js
const fs = require("fs");
const path = require("path");

const file = path.join(__dirname, "..", "web", "index.html");
const v = Date.now().toString(36);
let html = fs.readFileSync(file, "utf8");
// script do motor
html = html.replace(/src="index\.js(\?v=[^"]*)?"/, `src="index.js?v=${v}"`);
// pacote do jogo (index.pck): o carregador aceita um endereço próprio em "mainPack"
html = html.replace(/"mainPack":"[^"]*",?/, "");
html = html.replace(/const GODOT_CONFIG = \{/, `const GODOT_CONFIG = {"mainPack":"index.pck?v=${v}",`);
fs.writeFileSync(file, html);
console.log("versão", v);
