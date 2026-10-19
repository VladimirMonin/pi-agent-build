// Deterministic child provider, loaded by the actual detached Subagents runner.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

export default async function (pi) {
  const host = process.env.PI_PACKAGE_DIR;
  if (!host) throw Error('Explicit candidate host required');
  const sdkEntry = fs.realpathSync(path.join(host,'dist/index.js'));
  const sdk = await import(pathToFileURL(sdkEntry).href);
  const sdkRoot = fs.realpathSync(host);
  const metadataPath = path.join(sdkRoot,'package.json');
  const metadata = JSON.parse(fs.readFileSync(metadataPath,'utf8'));
  const hash = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const ai = await import(pathToFileURL(path.join(host, 'node_modules/@earendil-works/pi-ai/dist/index.js')).href);
  let childCwd, childSessionId;
  pi.registerProvider('coord-child', { api: 'openai-completions', baseUrl: 'https://mock.invalid', apiKey: 'synthetic',
    models: [{ id: 'mock', name: 'mock', reasoning: false, input: ['text'], contextWindow: 32768, maxTokens: 256,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }],
    streamSimple(model, context) {
      const stream = ai.createAssistantMessageEventStream();
      const last = context.messages.findLast(message => message.role !== 'system');
      const resume = JSON.stringify(last).includes('RESUME_CANARY');
      const content = resume ? [{ type: 'text', text: 'RESUMED_RESULT:84' }]
        : last?.role === 'toolResult'
          ? [{ type: 'text', text: JSON.stringify(last).includes('USE_42') ? 'CHILD_USEFUL_RESULT:42' : 'MISSING_SUPERVISOR_ANSWER' }]
          : [{ type: 'toolCall', id: 'supervisor-question', name: 'contact_supervisor',
            arguments: { reason: 'need_decision', message: 'SYNTHETIC_DECISION: Which number should the report contain?' } }];
      const message = { role: 'assistant', api: model.api, provider: model.provider, model: model.id,
        timestamp: Date.now(), content, stopReason: content[0].type === 'toolCall' ? 'toolUse' : 'stop',
        usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
      queueMicrotask(async () => {
        try {
          if (!resume && last?.role === 'toolResult' && JSON.stringify(last).includes('USE_42')) {
            fs.writeFileSync(path.join(childCwd,`completion-held-${process.pid}.json`),JSON.stringify({pid:process.pid,sessionId:childSessionId}));
            const deadline=Date.now()+20000;
            while(!fs.existsSync(path.join(childCwd,'release-initial-completion'))) {
              if(Date.now()>deadline)throw Error('Fixture completion gate timeout');
              await new Promise(resolve=>setTimeout(resolve,20));
            }
          }
          stream.push({ type: 'start', partial: message });
          stream.push({ type: 'done', reason: message.stopReason, message }); stream.end();
        } catch(error) {
          stream.push({type:'error',reason:'error',error:{...message,stopReason:'error',errorMessage:String(error)}});stream.end();
        }
      });
      return stream;
    } });
  pi.on('session_start', (_event, ctx) => {
    childCwd=ctx.cwd;childSessionId=ctx.sessionManager.getSessionId();
    const entrypoint=fs.realpathSync(process.argv[1]);
    // The active context must actually use the imported candidate SDK class;
    // merely echoing PI_PACKAGE_DIR would also pass for a foreign Pi process.
    const sdkIdentity={root:sdkRoot,entry:sdkEntry,entrySha256:hash(sdkEntry),name:metadata.name,version:metadata.version,
      packageSha256:hash(metadataPath),sessionManagerConstructorMatches:ctx.sessionManager.constructor===sdk.SessionManager};
    fs.writeFileSync(path.join(ctx.cwd, `child-${process.pid}.json`), JSON.stringify({
      pid: process.pid, ppid: process.ppid, execPath: process.execPath, host,
      sessionId: ctx.sessionManager.getSessionId(), cwd: ctx.cwd,
      entrypoint:{path:entrypoint,sha256:hash(entrypoint)},sdkIdentity,
    }));
  });
}
