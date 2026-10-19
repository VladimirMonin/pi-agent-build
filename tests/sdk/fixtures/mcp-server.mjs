// Dependency-free, synthetic stdio MCP server. No network, auth or filesystem writes.
import readline from 'node:readline';

const schema = { type: 'object', properties: { value: { type: 'integer', minimum: 1, maximum: 100,
  description: 'Synthetic positive integer to increment' } }, required: ['value'], additionalProperties: false };
const tools = ['probe', 'proxy_only'].map(name => ({ name, description: `Synthetic fixture ${name}: increment an integer`,
  inputSchema: schema, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false } }));
const input = readline.createInterface({ input: process.stdin });
for await (const line of input) {
  const request = JSON.parse(line);
  if (request.id === undefined) continue;
  let result, error;
  switch (request.method) {
    case 'initialize': result = { protocolVersion: request.params.protocolVersion,
      capabilities: { tools: {} }, serverInfo: { name: 'pi-build-synthetic-mcp', version: '1.0.0' } }; break;
    case 'ping': result = {}; break;
    case 'tools/list': result = { tools }; break;
    case 'resources/list': result = { resources: [] }; break;
    case 'resources/templates/list': result = { resourceTemplates: [] }; break;
    case 'prompts/list': result = { prompts: [] }; break;
    case 'tools/call': {
      const value = request.params.arguments?.value;
      if (!tools.some(tool => tool.name === request.params.name) || !Number.isInteger(value) || value < 1 || value > 100) {
        error = { code: -32602, message: 'Invalid synthetic call' }; break;
      }
      result = { content: [{ type: 'text', text: `FIXTURE_RESULT:${value + 1}` }], structuredContent: { incremented: value + 1 } };
      break;
    }
    default: error = { code: -32601, message: 'Unsupported synthetic method' };
  }
  process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: request.id, ...(error ? { error } : { result }) }) + '\n');
}
