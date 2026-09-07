import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync} from 'node:crypto';
import {approvalPayload,signApproval,signedApprovalVerdict} from './policy-approval.mjs';
const {privateKey,publicKey}=generateKeyPairSync('ed25519');
const config={version:1,keys:[{id:'app-1',operatorId:7,publicKey:publicKey.export({type:'spki',format:'pem'})}]};
const result={binding:{repo:'o/r',head:'a',base:'b',policyDigest:'c'}};
const payload=approvalPayload({binding:result.binding,operatorId:7,operationId:'op-1',issuedAt:'2026-09-07T00:00:00Z'});
const comment={id:1,body:signApproval(payload,'app-1',privateKey)};
test('signed single-owner authorization requires pinned key and matching full binding',()=>{
 assert.equal(signedApprovalVerdict(result,[comment],config,Date.parse('2026-09-08')).allowed,true);
 assert.equal(signedApprovalVerdict({...result,binding:{...result.binding,base:'changed'}},[comment],config).allowed,false);
 assert.equal(signedApprovalVerdict(result,[{...comment,body:comment.body.replace('op-1','forged')}],config).allowed,false);
 assert.equal(signedApprovalVerdict(result,[comment],{version:1,keys:[]}).reason,'signed_channel_unconfigured');
 assert.equal(signedApprovalVerdict(result,[comment],{version:1,keys:[{...config.keys[0],operatorId:8}]}).allowed,false);
});
test('mutable comments do not advertise durable revocation support; revoked trust keys refuse',()=>{
 assert.throws(()=>signApproval({...payload,action:'revoke'},'app-1',privateKey),/monotonic/);
 assert.throws(()=>approvalPayload({...payload,binding:result.binding,action:'revoke'}),/Invalid approval/);
 assert.equal(signedApprovalVerdict(result,[comment],{...config,keys:[{...config.keys[0],revoked:true}]}).allowed,false);
});
