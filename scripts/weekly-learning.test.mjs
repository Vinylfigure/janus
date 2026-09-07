import test from 'node:test';
import assert from 'node:assert/strict';
import {runWeekly,harvest,weeklyConfigurationRevision,closesTask} from './weekly-learning.mjs';
const ledger=(origin='incident-1')=>`## L-001 · 2026-09-07 · A learning\n- Scope: portable\n- Status: candidate\n- Rule: Check a source before changing behavior.\n- Trigger: A reproduced failure at https://github.com/o/child/issues/1\n- Origin: ${origin}\n`;
class Store{constructor(){this.n=0;this.state={version:1,generations:{},leases:{},operations:{}};}async read(){return {sha:this.n,state:structuredClone(this.state)};}async compareAndSwap(expected,state){if(expected!==this.n)return false;this.state=structuredClone(state);this.n++;return true;}}
function setup(){const store=new Store(),tasks=[],pulses=[];let creates=0;
 const client={sources:async()=>[{repo:'o/a',revision:'a',body:ledger()}],findOperation:async()=>tasks,preflight:async()=>{},createTask:async draft=>{creates++;const t={...draft,number:1};tasks.push(t);return t;},progress:async()=>({complete:false}),pulse:async p=>pulses.push(p)};
 const options={owner:'one',runId:'run1',now:()=>Date.parse('2026-09-07T10:00:00Z'),sourceRevision:'head',configurationRevision:'config'};
 return {store,client,tasks,pulses,options,get creates(){return creates;}};
}
test('duplicate siblings and repeated observations count once; unavailable is partial coverage',()=>{
 const sources=[{repo:'o/a',revision:'a',body:ledger()},{repo:'o/b',revision:'b',body:ledger()},{repo:'o/c',error:'403'}];
 const result=harvest(sources);assert.equal(result.candidates.length,1);assert.equal(result.candidates[0].provenance.length,2);assert.equal(result.complete,false);
 assert.equal(harvest(sources,{[result.candidates[0].id]:true}).candidates.length,0);
});
test('one bounded task is dispatched; next firing resumes it without duplication',async()=>{
 const f=setup();let result=await runWeekly(f.client,f.store,f.options);assert.equal(result.reason,'improvement_started');assert.equal(f.creates,1);assert.match(f.tasks[0].body,/@claude/);
 result=await runWeekly(f.client,f.store,{...f.options,runId:'run2'});assert.equal(result.reason,'existing_improvement_pending');assert.equal(f.creates,1);
 f.client.progress=async()=>({complete:true});result=await runWeekly(f.client,f.store,f.options);assert.equal(result.reason,'improvement_verified');
 result=await runWeekly(f.client,f.store,f.options);assert.equal(result.reason,'healthy_empty');assert.equal(f.creates,1);
});
test('an interrupted create is recovered from actual artifact and never resent',async()=>{
 const f=setup(),create=f.client.createTask;f.client.createTask=async d=>{await create(d);throw Error('lost response');};
 assert.equal((await runWeekly(f.client,f.store,f.options)).state,'failed');assert.equal(f.creates,1);
 assert.equal((await runWeekly(f.client,f.store,f.options)).reason,'existing_improvement_pending');assert.equal(f.creates,1);
});
test('a missing uncertain artifact holds instead of retrying the create',async()=>{
 const f=setup();f.client.createTask=async()=>{throw Error('uncertain');};await runWeekly(f.client,f.store,f.options);
 assert.equal((await runWeekly(f.client,f.store,f.options)).reason,'create_response_uncertain');
});
test('concurrent firings claim exactly one improvement',async()=>{
 const f=setup();const results=await Promise.all([runWeekly(f.client,f.store,f.options),runWeekly(f.client,f.store,{...f.options,owner:'two'})]);
 assert.equal(f.creates,1);assert.ok(results.some(r=>r.reason==='owned_elsewhere'));
});
test('healthy empty writes only execution receipt; missing coverage never reports healthy empty',async()=>{
 const f=setup();f.client.sources=async()=>[];
 assert.equal((await runWeekly(f.client,f.store,f.options)).reason,'healthy_empty');assert.equal(f.creates,0);assert.equal(f.pulses[0].state,'idle');
 f.client.sources=async()=>[{repo:'o/a',error:'unavailable'}];assert.equal((await runWeekly(f.client,f.store,f.options)).reason,'partial_coverage');assert.equal(f.pulses.at(-1).state,'failed');
});
test('the template title filter retains the existing harvest behavior',()=>{
 assert.equal(harvest([{repo:'o/child',revision:'a',body:ledger()}],{},ledger()).candidates.length,0);
});

test('pulse configuration hash matches Harness canonical empty fields and key ordering',async()=>{
 const {createHash}=await import('node:crypto');
 const loop={name:'weekly-learning',driver:'github-action',workflow:'weekly-learning.yml',enabled:true,schedule:'47 9 * * 1',allowedTools:[]};
 const expected=createHash('sha256').update(JSON.stringify({name:loop.name,driver:loop.driver,workflow:loop.workflow,enabled:loop.enabled,schedule:loop.schedule,skill:'',allowedTools:[],workflowRevision:'blob'})).digest('hex');
 assert.equal(weeklyConfigurationRevision(loop,'blob'),expected);
 assert.equal(weeklyConfigurationRevision({...loop,skill:''},'blob'),expected);
 assert.notEqual(weeklyConfigurationRevision(loop,'another-blob'),expected);
});
test('carrier PR names exactly the delivered task including newline-delimited references',()=>{
 assert.equal(closesTask('Weekly-operation: x\nCloses #12\nEvidence follows',12),true);
 assert.equal(closesTask('Closes #123',12),false);
 assert.equal(closesTask('Related to #12',12),false);
});
