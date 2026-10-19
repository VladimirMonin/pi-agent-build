import { createAssistantMessageEventStream, getCurrentTools } from '@earendil-works/pi-ai';

export default function (pi) {
  for (const name of ['fixture_allowed', 'fixture_forbidden']) pi.registerTool({ name, label: name, description: 'Synthetic no-op',
    parameters: { type: 'object', properties: {}, additionalProperties: false },
    async execute() { return { content: [{ type: 'text', text: 'synthetic' }], details: undefined }; } });
  pi.registerProvider('cli-fixture', { api: 'openai-completions', baseUrl: 'https://mock.invalid', apiKey: 'synthetic',
    models: ['normal', 'length'].map(id => ({ id, name: id, input: ['text'], reasoning: false, contextWindow: 65536, maxTokens: 128,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } })),
    streamSimple(model, context) {
      const stream = createAssistantMessageEventStream();
      const text = model.id === 'length' ? 'PARTIAL_PRINT_OUTPUT' : JSON.stringify({ activeTools: getCurrentTools(context.messages).map(tool => tool.name) });
      const output = model.id === 'length' ? model.maxTokens : 2;
      const message = { role: 'assistant', api: model.api, provider: model.provider, model: model.id, timestamp: Date.now(),
        content: [], stopReason: 'stop',
        usage: { input: 1, output, cacheRead: 0, cacheWrite: 0, totalTokens: 1 + output,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
      queueMicrotask(() => {
        stream.push({ type: 'start', partial: message });
        message.content = [{type:'text',text:''}];
        stream.push({type:'text_start',contentIndex:0,partial:message});
        message.content[0].text = text;
        stream.push({type:'text_delta',contentIndex:0,delta:text,partial:message});
        stream.push({type:'text_end',contentIndex:0,content:text,partial:message});
        message.stopReason = model.id === 'length' ? 'length' : 'stop';
        stream.push({ type: 'done', reason: message.stopReason, message }); stream.end();
      });
      return stream;
    } });
}
