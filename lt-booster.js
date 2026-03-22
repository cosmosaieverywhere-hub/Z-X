const localtunnel = require('localtunnel');
const http = require('http');

const server = http.createServer((req, res) => {
    res.writeHead(301, { "Location": "https://epic-ownership-smoke-orleans.trycloudflare.com" });
    res.end();
});
server.listen(3000);

(async () => {
    const tunnel = await localtunnel({ 
        port: 3000, 
        subdomain: 'zx-survival' 
    });
    console.log('✅ Entry Point Live: ' + tunnel.url);
})();
