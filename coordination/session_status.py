import json,os,sys
sys.stdout.reconfigure(encoding='utf-8')
b=os.path.join(os.environ['USERPROFILE'],'.kiro','sessions','48374e8b85ea0326')
M={'01':'sess_09e380dd-9f1d-4e79-bd9d-a8ee6e8f6060','02':'sess_ba672768-af8c-4e4c-b2f9-9626bf426df3','03':'sess_d4b65ace-37ad-4e88-8f41-8a27d824a646','04':'sess_a24d01e7-e535-413c-9ff6-d5258090820b','05':'sess_480b589a-e86a-47ff-bada-af6f34aa4635','06':'sess_43bd48be-841d-47c1-b0ed-039856dc1f45','07':'sess_dcb1b9cb-33ef-476d-81e4-8bbd8292bda5','08':'sess_89969e92-ce80-4028-b734-9037d026027a','09':'sess_6ce8ebb1-4e45-454d-a561-e0bad09a8be5','10':'sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce','11':'sess_9129b680-f80d-45db-bb67-9ead14c05df8','12':'sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2'}
since=sys.argv[1]
for k,s in M.items():
    R=[]
    for x in open(os.path.join(b,s,'messages.jsonl'),encoding='utf-8',errors='replace').read().splitlines()[-300:]:
        try: p=json.loads(x)
        except Exception: continue
        if p.get('timestamp','')>=since: R.append(p)
    T=[p['payload'].get('type') for p in R]
    F=sum(1 for p in R if p['payload'].get('type')=='usage_summary' and p['payload'].get('status')=='failed')
    last=R[-1]['payload'].get('type') if R else None
    print(k,'start',T.count('turn_start'),'tools',T.count('tool_call'),'fail',F,'last',last)