import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{"content-type":"application/json","cache-control":"no-store"}});
const norm=(v:unknown)=>String(v??"").toLowerCase().normalize("NFKD").replace(/[^a-z0-9]/g,"");
Deno.serve(async(req:Request)=>{
 const url=Deno.env.get("SUPABASE_URL")!,service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 const db=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const supplied=req.headers.get("x-bridgepoint-book-monitor-token")??"";
 const {data:secret,error:secretErr}=await db.schema("automation").from("book_monitor_secret_v5595").select("token").eq("singleton",true).maybeSingle();
 if(secretErr||!secret?.token||supplied!==secret.token)return json({ok:false,error:"unauthorized"},401);
 let best:any=null,inspected=0;const errors:string[]=[];
 try{
  const q='intitle:"The Map I Didn\'t Have" inauthor:"Kole Johnson"';
  const api="https://www.googleapis.com/books/v1/volumes?maxResults=10&projection=full&fields=items(id,volumeInfo(title,authors,imageLinks,canonicalVolumeLink,infoLink),saleInfo(saleability,buyLink,retailPrice))&q="+encodeURIComponent(q);
  const res=await fetch(api,{headers:{"accept":"application/json","user-agent":"BridgePoint-Book-Monitor/1.1"}});
  if(!res.ok)errors.push("google_books_"+res.status);
  else{
   const data=await res.json();
   for(const item of Array.isArray(data?.items)?data.items:[]){
    inspected++;const vi=item?.volumeInfo??{},si=item?.saleInfo??{};
    const title=norm(vi.title),authors=(Array.isArray(vi.authors)?vi.authors:[]).map(norm);
    if(title!=="themapididnthave"||!authors.some((a:string)=>a.includes("kolejohnson")))continue;
    const buy=String(si.buyLink??""),sale=String(si.saleability??"");
    const live=!!buy&&["FOR_SALE","FOR_SALE_AND_RENTAL"].includes(sale);
    const score=(live?100:0)+(buy?20:0)+(sale==="FOR_PREORDER"?10:0)+1;
    if(!best||score>best.score)best={score,item,vi,si};
   }
  }
 }catch(e){errors.push(String((e as any)?.message??e))}
 let status="PENDING_VERIFICATION",volumeId="",purchaseUrl="",coverUrl="",infoUrl="",saleability="",amount:number|null=null,currency="";
 if(best){const {item,vi,si}=best;volumeId=String(item?.id??"");purchaseUrl=String(si?.buyLink??"");infoUrl=String(vi?.canonicalVolumeLink??vi?.infoLink??"");coverUrl=String(vi?.imageLinks?.extraLarge??vi?.imageLinks?.large??vi?.imageLinks?.medium??vi?.imageLinks?.small??vi?.imageLinks?.thumbnail??"").replace(/^http:/,"https:");saleability=String(si?.saleability??"");amount=Number.isFinite(Number(si?.retailPrice?.amount))?Number(si.retailPrice.amount):null;currency=String(si?.retailPrice?.currencyCode??"");if(purchaseUrl&&["FOR_SALE","FOR_SALE_AND_RENTAL"].includes(saleability))status="LIVE";else if(saleability==="FOR_PREORDER"&&purchaseUrl)status="PREORDER";else status="LISTED_NOT_FOR_SALE"}
 const {data:recorded,error:recordErr}=await db.schema("automation").rpc("record_book_google_play_probe_v5595",{p_token:supplied,p_status:status,p_volume_id:volumeId,p_purchase_url:purchaseUrl,p_cover_url:coverUrl,p_info_url:infoUrl,p_saleability:saleability,p_list_price_amount:amount??0,p_list_price_currency:currency,p_metadata:{source:"GOOGLE_BOOKS_API",probe_ok:errors.length===0,inspected,errors,matched:!!best,checked_at:new Date().toISOString()}});
 if(recordErr)return json({ok:false,error:recordErr.message,status,inspected,errors},500);
 return json({ok:true,status,inspected,matched:!!best,errors,book:recorded});
});