/** The app authenticates the operator before signing. CI receives public keys only. */
import { sign, verify } from 'node:crypto';
import { hash,stable } from './effect-policy.mjs';
export const APPROVAL_MARKER='<!-- overlord:policy-approval:v1 -->';
export function approvalPayload({binding,operatorId,operationId,issuedAt,action='merge'}) {
  if(action!=='merge'||!Number.isSafeInteger(operatorId)||operatorId<1||!operationId||!Number.isFinite(Date.parse(issuedAt)))throw Error('Invalid approval action');
  return {version:1,action,bindingHash:hash(binding),operatorId,operationId,issuedAt};
}
export function signApproval(payload,keyId,privateKey) {
  if(!keyId||payload?.action!=='merge')throw Error('Only merge approval issuance is supported; durable revocation needs a trusted monotonic store');
  const envelope={payload,keyId,signature:sign(null,Buffer.from(stable(payload)),privateKey).toString('base64')};
  return `${APPROVAL_MARKER}\n${JSON.stringify(envelope)}`;
}
export function signedApprovalVerdict(result,comments,config,now=Date.now()) {
  if(!Array.isArray(config?.keys)||config.version!==1)return {allowed:false,reason:'signed_channel_unconfigured'};
  const events=[];
  for(const c of comments??[]){
    const body=(c.body??'').trim();if(!body.startsWith(APPROVAL_MARKER+'\n'))continue;
    try{
      const envelope=JSON.parse(body.slice(APPROVAL_MARKER.length+1)),p=envelope.payload;
      const key=config.keys.find(k=>k.id===envelope.keyId&&k.operatorId===p.operatorId&&!k.revoked);
      if(!key||p.version!==1||p.action!=='merge'||typeof p.operationId!=='string'||!p.operationId||p.bindingHash!==hash(result.binding))continue;
      const at=Date.parse(p.issuedAt);if(!Number.isFinite(at)||at>now+60_000)continue;
      if(!verify(null,Buffer.from(stable(p)),key.publicKey,Buffer.from(envelope.signature,'base64')))continue;
      events.push({p,at,commentId:c.id});
    }catch{}
  }
  events.sort((a,b)=>a.at-b.at);
  const latest=events.at(-1);
  return latest?.p.action==='merge'?{allowed:true,reason:'signed_operator_approval',operationId:latest.p.operationId,commentId:latest.commentId}:{allowed:false,reason:config.keys.length?'current_approval_required':'signed_channel_unconfigured'};
}
