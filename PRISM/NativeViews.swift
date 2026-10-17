import SwiftUI
import PhotosUI
import ImageIO

@MainActor struct NativeAdminRoot: View {
 @ObservedObject var store: AdminStore
 var body: some View {
  Group {
   if store.checking { VStack(spacing:20) { Image(systemName:"shield.lefthalf.filled").font(.system(size:54)).foregroundStyle(gold); Text("Prism Admin").font(.largeTitle.bold()); ProgressView() }.frame(maxWidth:.infinity,maxHeight:.infinity).background(canvas) }
   else if !store.authenticated { NativeLogin(store:store) }
   else { TabView(selection:$store.selectedTab) {
    if store.role != "support" {
     NavigationStack { NativeDashboard(store:store) }.tabItem { Label("Panoramica",systemImage:"square.grid.2x2") }.tag("dashboard")
     NavigationStack { NativeModule(store:store,module:Catalog.module("users")) }.tabItem { Label("Utenti",systemImage:"person.2") }.tag("users")
     NavigationStack { NativeModule(store:store,module:Catalog.module("photos")) }.tabItem { Label("Foto",systemImage:"photo.on.rectangle") }.badge((store.counts["photos"] as? Int) ?? 0).tag("photos")
    }
    NavigationStack { NativeModule(store:store,module:Catalog.module("support")) }.tabItem { Label("Assistenza",systemImage:"bubble.left.and.bubble.right") }.badge((store.counts["support"] as? Int) ?? 0).tag("support")
    NavigationStack(path:$store.managementPath) { NativeManagement(store:store).navigationDestination(for:String.self) { id in NativeModule(store:store,module:Catalog.module(id)) } }.tabItem { Label("Gestione",systemImage:"slider.horizontal.3") }.badge(((store.counts["reports"] as? Int) ?? 0) + ((store.counts["verification"] as? Int) ?? 0)).tag("more")
   }.tint(gold) }
  }.preferredColorScheme(.dark).environmentObject(store)
   .task { await store.restore() }
   .alert("Prism Admin",isPresented:Binding(get:{!store.alert.isEmpty},set:{if !$0 {store.alert=""}})) { Button("OK") { store.alert="" } } message: { Text(store.alert) }
 }
}
@MainActor struct NativeLogin: View {
 @ObservedObject var store: AdminStore
 @State private var email=""
 @State private var password=""
 @State private var error=""
 @State private var busy=false
 var body: some View {
  ScrollView { VStack(alignment:.leading,spacing:28) {
   Image(systemName:"shield.lefthalf.filled").font(.system(size:48)).foregroundStyle(gold).padding(.top,60)
   VStack(alignment:.leading,spacing:10) { Text("Prism Admin").font(.system(size:38,weight:.bold)); Text("Il controllo, ovunque.").font(.title3).foregroundStyle(.secondary) }
   VStack(alignment:.leading,spacing:18) {
    Text("Bentornato").font(.title2.bold())
    TextField("Email amministratore",text:$email).keyboardType(.emailAddress).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled().padding().background(canvas,in:RoundedRectangle(cornerRadius:16))
    SecureField("Password",text:$password).textContentType(.password).padding().background(canvas,in:RoundedRectangle(cornerRadius:16))
    if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red) }
    Button { busy=true;error=""; Task { do { try await store.login(email:email,password:password);password="" } catch {self.error=error.localizedDescription};busy=false } } label: { HStack { Spacer(); if busy {ProgressView()} else {Text("Accedi").bold();Image(systemName:"arrow.right")};Spacer() }.padding() }.buttonStyle(.borderedProminent).tint(gold).foregroundStyle(.black).disabled(busy || email.isEmpty || password.isEmpty)
   }.padding(22).background(panel,in:RoundedRectangle(cornerRadius:26))
   Label("Accesso riservato agli amministratori",systemImage:"lock.shield").font(.footnote).foregroundStyle(.secondary)
  }.padding(24) }.background(canvas)
 }
}
@MainActor struct NativeDashboard: View {
 @ObservedObject var store: AdminStore
 @State private var data:Object=[:]
 @State private var busy=false
 @State private var error=""
 var body: some View {
  ScrollView { VStack(alignment:.leading,spacing:22) {
   HStack { VStack(alignment:.leading,spacing:6) { Text("Ciao, \(store.name)").font(.largeTitle.bold());Text("La tua community, a colpo d’occhio.").foregroundStyle(.secondary) };Spacer();Image(systemName:"shield.lefthalf.filled").font(.title).foregroundStyle(gold) }
   Text("DA GESTIRE").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(gold)
   ForEach((["photos","reports","support"] + (store.role == "owner" ? ["verification"] : [])),id:\.self) { id in let m=Catalog.module(id)
    NavigationLink { NativeModule(store:store,module:m) } label: { HStack(spacing:16) { Image(systemName:string(m["icon"])).frame(width:44,height:44).foregroundStyle(gold).background(gold.opacity(0.1),in:RoundedRectangle(cornerRadius:14));VStack(alignment:.leading) {Text(string(m["title"])).font(.headline);Text(string(m["subtitle"])).font(.caption).foregroundStyle(.secondary)};Spacer();Text(string(store.counts[id] ?? 0)).font(.title2.bold()).foregroundStyle(gold);Image(systemName:"chevron.right").font(.caption) }.padding(18).background(panel,in:RoundedRectangle(cornerRadius:22)) }.buttonStyle(.plain)
   }
   if !error.isEmpty { RetryBox(text:error) { Task {await load()} } }
   LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:14) {
    ForEach(["users","new_users","online","suspended"],id:\.self) { key in VStack(alignment:.leading,spacing:10) { Text(Catalog.label(key)).font(.caption).foregroundStyle(.secondary); Text(string(object(data["stats"])[key] ?? "—")).font(.system(size:32,weight:.semibold)) }.frame(maxWidth:.infinity,alignment:.leading).padding(20).background(panel,in:RoundedRectangle(cornerRadius:22)) }
   }
   if let trend=data["trend"] as? [Object],!trend.isEmpty { TrendView(rows:trend) }
  }.padding(20) }.background(canvas).navigationTitle("Panoramica").navigationBarTitleDisplayMode(.inline).toolbar { Button {Task {await load()}} label: {Image(systemName:"arrow.clockwise")} }.refreshable {await load()}.task {await load()}.onChange(of:store.contentRevision){_ in Task{await load()}}.overlay {if busy && data.isEmpty {ProgressView()}}
 }
 func load() async {busy=true;defer{busy=false};do{data=try await store.request("/dashboard");error="";await store.refreshCounts()}catch{self.error=error.localizedDescription}}
}
@MainActor struct TrendView:View {
 let rows:[Object]
 var body:some View { VStack(alignment:.leading,spacing:14) { Text("Nuove iscrizioni").font(.headline);GeometryReader { geo in HStack(alignment:.bottom,spacing:4) { ForEach(Array(rows.enumerated()),id:\.offset) { _,r in let maximum=rows.map{($0["total"] as? Double) ?? 0}.max() ?? 1;RoundedRectangle(cornerRadius:3).fill(gold.gradient).frame(height:max(3,geo.size.height * CGFloat((r["total"] as? Double ?? 0)/max(1,maximum)))) } } }.frame(height:90);Text("Ultimi \(rows.count) giorni").font(.caption).foregroundStyle(.secondary) }.padding(20).background(panel,in:RoundedRectangle(cornerRadius:22)) }
}
@MainActor struct NativeManagement: View {
 @ObservedObject var store: AdminStore
 var body: some View {
  List {
   Section("Strumenti") {
    ForEach(Catalog.modules.filter { store.allowed($0) && !["dashboard","users","photos","support"].contains(string($0["id"])) }, id: \.idString) { module in
     NavigationLink(value: string(module["id"])) {
      Label {
       HStack {
        Text(string(module["title"]))
        Spacer()
        if let n = store.counts[string(module["id"])] as? Int, n > 0 { Text("\(n)").foregroundStyle(gold) }
       }
      } icon: { Image(systemName: string(module["icon"])).foregroundStyle(gold) }
     }
    }
   }
   Section {
    Label(store.name, systemImage: "person.crop.circle")
    Label(Catalog.display(store.role), systemImage: "lock.shield")
    Button("Esci dall’account", role: .destructive) {
     Task { do { try await store.logout() } catch { store.alert = error.localizedDescription } }
    }
   }
  }.scrollContentBackground(.hidden).background(canvas).navigationTitle("Gestione")
 }
}
extension Dictionary where Key==String,Value==Any { var idString:String {string(self["id"])} }
@MainActor struct RetryBox:View {let text:String;let retry:()->Void;var body:some View {VStack(spacing:12){Label(text,systemImage:"wifi.exclamationmark").font(.callout);Button("Riprova",action:retry)}.frame(maxWidth:.infinity).padding()}}

@MainActor struct NativeModule:View {
 @ObservedObject var store:AdminStore
 let module:Object
 @State private var data:Object=[:]
 @State private var rows:[Object]=[]
 @State private var q=""
 @State private var filter=""
 @State private var offset=0
 @State private var error=""
 @State private var busy=false
 @State private var reloadQueued=false
 @State private var visible=false
 @State private var form:NativeFormSpec?
 var moduleID:String {string(module["id"])}
 var body:some View { List {
  if module["search"] as? Bool == true { HStack {Image(systemName:"magnifyingglass").foregroundStyle(.secondary);TextField("Cerca nome o email",text:$q).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search).onSubmit {Task{await load()}};if !q.isEmpty{Button{q="";Task{await load()}}label:{Image(systemName:"xmark.circle.fill")}} } }
  if !objects(module["filters"]).isEmpty { Picker("Mostra",selection:$filter){ForEach(objects(module["filters"]),id:\.optionValue){o in Text(string(o["label"])).tag(string(o["value"]))}}.onChange(of:filter){_ in Task{await load()}} }
  ForEach(Array(objects(module["create"]).enumerated()),id:\.offset){_,a in Button {form=NativeFormSpec(action:a,context:data)} label:{Label(string(a["title"]),systemImage:"plus.circle")}.foregroundStyle(gold).disabled(busy || data.isEmpty) }
  if module["kind"] as? String == "stats" { NativeInfo(data:data) }
  ForEach(module["summary"] as? [String] ?? [],id:\.self){ key in Section(Catalog.label(key)){if let d=data[key] as? Object{NativeInfo(data:d)}else{Text(Catalog.display(data[key]))}} }
  if !error.isEmpty {RetryBox(text:error){Task{await load()}}}
  Section {
   ForEach(Array(rows.enumerated()),id:\.offset){_,row in rowView(row)}
   if rows.isEmpty && !busy && error.isEmpty && module["kind"] as? String != "stats" { VStack(spacing:10){Image(systemName:string(module["icon"])).font(.largeTitle).foregroundStyle(gold);Text("Nessun elemento").font(.headline);Text("Gli aggiornamenti compariranno qui.").font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity).padding(25) }
   if rows.count < (data["total"] as? Int ?? rows.count) {Button("Carica altri"){Task{await load(more:true)}}.disabled(busy)}
  }
  ForEach(Array(objects(module["groups"]).enumerated()),id:\.offset){_,group in Section(string(group["title"])){ForEach(Array(objects(data[string(group["key"])]).enumerated()),id:\.offset){_,row in NavigationLink {NativeRowDetail(store:store,module:group,row:row)}label:{ModuleRow(module:group,row:row)}}}}
 }.scrollContentBackground(.hidden).background(canvas).navigationTitle(string(module["title"])).toolbar {Button{Task{await load()}}label:{Image(systemName:"arrow.clockwise")}}.overlay{if busy && rows.isEmpty && data.isEmpty{ProgressView()}}.refreshable{await load()}.task{if filter.isEmpty{filter=string(objects(module["filters"]).first?["value"])};await load()}.onAppear{visible=true}.onDisappear{visible=false}.onChange(of:store.contentRevision){_ in if visible{Task{await load()}}}.sheet(item:$form,onDismiss:{Task{await load()}}){ spec in NativeForm(store:store,spec:spec){} }
 }
 @ViewBuilder func rowView(_ row:Object)->some View {
  if moduleID=="users" {NavigationLink {NativeUser(store:store,uid:string(row["id"]))}label:{ModuleRow(module:["rowTitle":["name"],"rowSubtitle":["email","suspension_reason"]],row:row)}}
  else if moduleID=="photos" {NavigationLink {NativePhotoReview(store:store,row:row)}label:{HStack(spacing:14){NativePhoto(source:string(row["photo"])).frame(width:64,height:76).clipShape(RoundedRectangle(cornerRadius:14));VStack(alignment:.leading){Text(string(row["name"])).font(.headline);Text(Catalog.display(row["status"])).font(.caption).foregroundStyle(gold)}}}}
  else if moduleID=="verification" {NavigationLink{NativeVerification232(store:store,rid:string(row["id"]))}label:{ModuleRow(module:module,row:row)}}
  else if moduleID=="support" {NavigationLink{NativeTicket(store:store,tid:string(row["id"]))}label:{ModuleRow(module:["rowTitle":["subject"],"rowSubtitle":["name","status","updated_at"]],row:row)}}
  else {NavigationLink{NativeRowDetail(store:store,module:module,row:row)}label:{ModuleRow(module:moduleID=="reports" ? ["id":"reports","rowTitle":["target_name"],"rowSubtitle":["reason","status"]] : module,row:row)}}
 }
 func load(more:Bool=false) async {guard !busy else{if !more{reloadQueued=true};return};busy=true;let revision=store.contentRevision;defer{busy=false;if reloadQueued{reloadQueued=false;if visible{Task{await load()}}}};let next=more ? offset+25 : 0;var components=URLComponents();components.queryItems=[URLQueryItem(name:"offset",value:String(next)),URLQueryItem(name:"q",value:q),URLQueryItem(name:string(module["filterParam"] ?? "status"),value:filter.isEmpty ? "all":filter)];do{let response=try await store.request(string(module["path"])+(components.string ?? ""));guard revision==store.contentRevision else{reloadQueued=true;return};data=response;let new=objects(response[string(module["rows"] ?? "items")]);rows=more ? rows+new:new;offset=next;error=""}catch{self.error=error.localizedDescription}}
}
extension Dictionary where Key==String,Value==Any {var optionValue:String{string(self["value"])}}
@MainActor struct ModuleRow:View {let module:Object,row:Object;var body:some View {HStack(spacing:14){Image(systemName:string(module["icon"] ?? "person.crop.circle")).foregroundStyle(gold).frame(width:32);VStack(alignment:.leading,spacing:6){Text((module["rowTitle"] as? [String] ?? ["name","title","subject","email","action"]).compactMap{let s=string(row[$0]);return s.isEmpty ? nil:s}.first ?? "Elemento").font(.headline);ForEach(module["rowSubtitle"] as? [String] ?? ["status","created_at"],id:\.self){key in if let v=row[key],!(v is NSNull){Text(Catalog.display(v)).font(.caption).foregroundStyle(.secondary).lineLimit(2)}}}.padding(.vertical,6)}}}
@MainActor struct NativeInfo:View {
 let data:Object
 var body:some View {ForEach(data.keys.sorted().filter{!["photos","photo","photo_hash","photo_reviews","profile_revision","messages","items","trend","subscriptions","token_hash","admin_id","user_id","id"].contains($0)},id:\.self){key in info(key,data[key])}}
 func info(_ key:String,_ v:Any?)->AnyView {
  if let child=v as? Object {return AnyView(DisclosureGroup(Catalog.label(key)){NativeInfo(data:child)})}
  if let array=v as? [Object] {return AnyView(DisclosureGroup(Catalog.label(key)){ForEach(Array(array.enumerated()),id:\.offset){_,child in NativeInfo(data:child)}})}
  if let array=v as? [String] {return AnyView(VStack(alignment:.leading,spacing:6){Text(Catalog.label(key)).font(.caption).foregroundStyle(.secondary);Text(array.joined(separator:" · "))})}
  let raw=string(v);if raw.hasPrefix("data:"){return AnyView(EmptyView())}
  return AnyView(VStack(alignment:.leading,spacing:6){Text(Catalog.label(key)).font(.caption).foregroundStyle(.secondary);Text(Catalog.display(v)).font(.body).textSelection(.enabled)}.padding(.vertical,4))
 }
}
@MainActor struct NativeRowDetail:View {
 @ObservedObject var store:AdminStore
 let module:Object,row:Object
 @State private var form:NativeFormSpec?
 @State private var completed=false
 @Environment(\.dismiss) private var dismiss
 var actions: [Object] {
  if string(module["id"]) == "reports" {
   let fields: [Object] = [
    ["key":"status", "label":"Stato", "type":"select", "source":"status", "default":"reviewing", "options":[["value":"open","label":"Aperta"],["value":"reviewing","label":"In esame"],["value":"closed","label":"Chiusa"]]],
    ["key":"note", "label":"Nota amministrativa", "source":"admin_note", "type":"long"]
   ]
   return [["title":"Aggiorna segnalazione","method":"PUT","path":"/reports/{id}","fields":fields]]
  }
  return objects(module["actions"])
 }
 var body:some View {List{
  if string(module["id"])=="stories",let payload=row["payload"] as? Object {if let image=payload["image"] as? String{NativePhoto(source:image).frame(height:250)};NativeInfo(data:payload)}
  NativeInfo(data:row)
  if let uid=(row["target"] ?? row["user_id"]) as? String {NavigationLink("Apri profilo"){NativeUser(store:store,uid:uid)}}
  ForEach(Array(actions.enumerated()),id:\.offset){_,a in Button(string(a["title"]),role:a["danger"] as? Bool == true ? .destructive:nil){form=NativeFormSpec(action:a,context:row)}}
 }.scrollContentBackground(.hidden).background(canvas).navigationTitle(string(module["title"] ?? "Dettaglio")).sheet(item:$form,onDismiss:{if completed{dismiss()}}){spec in NativeForm(store:store,spec:spec){completed=true}}}
}
@MainActor struct NativeUser:View {
 @ObservedObject var store:AdminStore
 let uid:String
 @State private var data:Object=[:]
 @State private var error=""
 @State private var form:NativeFormSpec?
 @State private var busy=false
 var body:some View {List{
  if busy && data.isEmpty{ProgressView()}
  if !error.isEmpty{RetryBox(text:error){Task{await load()}}}
  if !data.isEmpty {
   if let photos=data["photos"] as? [String],!photos.isEmpty {ScrollView(.horizontal){HStack{ForEach(Array(photos.enumerated()),id:\.offset){i,photo in VStack{NativePhoto(source:photo).frame(width:125,height:155).clipShape(RoundedRectangle(cornerRadius:18));Text(i==0 ? "Principale":"Foto \(i+1)").font(.caption)}}}}}
   Section("Profilo e account"){NativeInfo(data:data)}
   if store.role=="owner"{Button{form=NativeFormSpec(action:["title":"Modifica profilo","method":"PUT","path":"/users/{id}/profile","fields":Catalog.data["profile"] ?? []],context:data,profile:true)}label:{Label("Modifica tutto il profilo",systemImage:"pencil.circle.fill")}.foregroundStyle(gold)}
   if store.role=="owner" {Section("Email di registrazione"){
    Label(data["email_verified_at"] == nil || data["email_verified_at"] is NSNull ? "Email non verificata":"Email verificata",systemImage:"envelope.badge.shield.half.filled")
    ForEach(Array(registrationEmailActions.enumerated()),id:\.offset){_,a in Button(string(a["title"])){form=NativeFormSpec(action:a,context:data)}}
   }}
   Section("Gestisci account"){ForEach(Array((objects(Catalog.data["userActions"])+(store.role=="owner" ? objects(Catalog.data["ownerActions"]):[])).enumerated()),id:\.offset){_,a in Button(string(a["title"]),role:a["danger"] as? Bool == true ? .destructive:nil){form=NativeFormSpec(action:a,context:data)}}}
  }
 }.scrollContentBackground(.hidden).background(canvas).navigationTitle(string(data["name"]).isEmpty ? "Profilo":string(data["name"])).task{await load()}.refreshable{await load()}.onChange(of:store.contentRevision){_ in Task{await load()}}.sheet(item:$form){spec in NativeForm(store:store,spec:spec){} }
 }
 var registrationEmailActions:[Object]{[
 ["title":"Verifica email manualmente","path":"/users/{id}/verify-registration-email","method":"POST","danger":true,"help":"Conferma soltanto dopo aver verificato l'identità dell'utente. Sblocca l'accesso senza OTP.","fields":[["key":"reason","label":"Motivo della verifica manuale","type":"long","required":true]]],
 ["title":"Modifica indirizzo email","path":"/users/{id}/change-registration-email","method":"POST","danger":true,"fields":[["key":"email","label":"Nuovo indirizzo email","type":"text","required":true],["key":"reason","label":"Motivo della modifica","type":"long","required":true]]],
 ["title":"Reinvia codice OTP","path":"/users/{id}/resend-registration-code","method":"POST","fields":[["key":"reason","label":"Nota amministrativa (facoltativa)","type":"long"]]]
 ]}
 func load()async{busy=true;defer{busy=false};do{data=try await store.request("/users/"+uid);error=""}catch{self.error=error.localizedDescription}}
}
@MainActor struct NativePhotoReview:View {
 @ObservedObject var store:AdminStore
 let row:Object
 @State private var note=""
 @State private var busy=false
 @State private var completed=false
 @Environment(\.dismiss) private var dismiss
 @State private var error=""
 @State private var form:NativeFormSpec?
 @State private var rejectConfirmation=false
 var body:some View {List {
  NativePhoto(source:string(row["photo"])).frame(maxWidth:.infinity).frame(height:320).clipShape(RoundedRectangle(cornerRadius:20))
  LabeledContent("Profilo",value:string(row["name"]))
  NavigationLink("Apri profilo"){NativeUser(store:store,uid:string(row["user_id"]))}
  TextField("Motivo del rifiuto / nota",text:$note,axis:.vertical).lineLimit(3...6)
  if !error.isEmpty{Text(error).foregroundStyle(.red)}
  HStack {Button("Approva"){Task{await decide("approved")}}.buttonStyle(.borderedProminent).tint(gold).foregroundStyle(.black);Spacer();Button("Rifiuta",role:.destructive){rejectConfirmation=true}.buttonStyle(.bordered)}.disabled(busy)
   Button("Rimuovi dal profilo", role:.destructive) {
   form=NativeFormSpec(action:["title":"Rimuovi foto","path":"/users/{id}/remove-photo","method":"POST","danger":true,"fields":[["key":"photo_hash","type":"hidden","source":"photo_hash"],["key":"reason","label":"Motivo","type":"long"]]],context:["id":row["user_id"] ?? "","photo_hash":row["photo_hash"] ?? ""])
  }.disabled(busy)
 }.scrollContentBackground(.hidden).background(canvas).navigationTitle("Verifica foto")
  .confirmationDialog("Rifiutare questa foto?",isPresented:$rejectConfirmation,titleVisibility:.visible){Button("Rifiuta",role:.destructive){Task{await decide("rejected")}}}
  .sheet(item:$form,onDismiss:{if completed{dismiss()}}){spec in NativeForm(store:store,spec:spec){completed=true}}
 }
 func decide(_ status:String)async{guard !busy else{return};busy=true;defer{busy=false};do{_=try await store.request("/photos/"+string(row["user_id"])+"/"+string(row["photo_hash"]),method:"PUT",body:["status":status,"note":note]);store.didMutate();dismiss();await store.refreshCounts()}catch{self.error=error.localizedDescription}}
}
@MainActor struct NativeTicket:View {
 @ObservedObject var store:AdminStore
 let tid:String
 @State private var data:Object=[:]
 @State private var reply=""
 @State private var error=""
 @State private var busy=false
 @Environment(\.dismiss) private var dismiss
 var body:some View { VStack(spacing:0){ScrollView{LazyVStack(alignment:.leading,spacing:16){
  HStack{Text(string(data["subject"])).font(.title2.bold());Spacer();Text(Catalog.display(data["status"])).font(.caption).foregroundStyle(gold)}
  ForEach(Array(objects(data["messages"]).enumerated()),id:\.offset){_,message in let own=message["from_admin"] as? Bool == true;HStack{if own{Spacer(minLength:30)};VStack(alignment:.leading,spacing:8){Text(own ? "Team Prism":string(data["name"])).font(.caption.bold()).foregroundStyle(gold);Text(string(message["body"])).textSelection(.enabled);Text(Catalog.display(message["created_at"])).font(.caption2).foregroundStyle(.secondary)}.padding(16).background(own ? gold.opacity(0.12):panel,in:RoundedRectangle(cornerRadius:20));if !own{Spacer(minLength:30)}}}
  if !error.isEmpty{Text(error).foregroundStyle(.red)}
 }.padding(20)}.refreshable{await load()}
 if string(data["status"]) != "closed" {HStack(alignment:.bottom,spacing:12){TextField("Scrivi una risposta…",text:$reply,axis:.vertical).lineLimit(1...6).padding(14).background(panel,in:RoundedRectangle(cornerRadius:20));Button{Task{await send()}}label:{Image(systemName:"arrow.up.circle.fill").font(.system(size:38))}.disabled(reply.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || busy)}.padding(16).background(canvas)}
 }.background(canvas).navigationTitle("Assistenza").navigationBarTitleDisplayMode(.inline)
  .toolbar {
   Menu {
    ForEach(["open", "reviewing", "closed"], id: \.self) { status in
     Button(Catalog.display(status)) { Task { await changeStatus(status) } }
    }
   } label: { Image(systemName: "ellipsis.circle") }
  }.task { await load() }
 }
 func load()async{do{data=try await store.request("/support/"+tid);error=""}catch{self.error=error.localizedDescription}}
 func changeStatus(_ status:String) async {
  do {
   _ = try await store.request("/support/" + tid, method:"PUT", body:["status":status])
   store.didMutate()
   if status=="closed"{dismiss()}else{await load()}
   await store.refreshCounts()
  } catch { self.error = error.localizedDescription }
 }
 func send()async{busy=true;defer{busy=false};do{_=try await store.request("/support/"+tid+"/reply",method:"POST",body:["body":reply]);reply="";store.didMutate();await load();await store.refreshCounts()}catch{self.error=error.localizedDescription}}
}
@MainActor struct NativePhoto:View {
 let source:String
 @State private var image:UIImage?
 var body:some View { ZStack{panel;if let image=image{Image(uiImage:image).resizable().scaledToFit()}else{Image(systemName:"photo").foregroundStyle(.secondary)}}.task(id:source){image=nil;if source.hasPrefix("data:"),let split=source.firstIndex(of:","),let bytes=Data(base64Encoded:String(source[source.index(after:split)...])){image=thumbnail(bytes)}else if let url=URL(string:source),url.scheme=="https",["api.prismdating.app","prismdating.app"].contains(url.host ?? ""){if let (bytes,_)=try? await URLSession.shared.data(from:url){image=thumbnail(bytes)}}} }
}
func thumbnail(_ data:Data)->UIImage? {guard let source=CGImageSourceCreateWithData(data as CFData,nil),let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1600,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary)else{return nil};return UIImage(cgImage:image)}

@MainActor struct NativeVerification232:View {
 @ObservedObject var store:AdminStore
 let rid:String
 @State private var data:Object=[:]
 @State private var error=""
 @State private var form:NativeFormSpec?
 @State private var completed=false
 @Environment(\.dismiss) private var dismiss
 var body:some View {List{
  if !error.isEmpty{RetryBox(text:error){Task{await load()}}}
  if !data.isEmpty{
   Section{Text(string(data["name"])).font(.title2.bold());Text(string(data["email"])).foregroundStyle(.secondary);Text("Codice sul foglio: Prism "+string(data["code"])).font(.headline).foregroundStyle(gold)}
   if string(data["status"])=="pending"{
    Section("Foto del profilo approvata"){NativePhoto(source:string(data["reference_photo"])).frame(maxWidth:.infinity).frame(height:210).clipShape(RoundedRectangle(cornerRadius:18))}
    Section("Selfie ricevuto"){NativePhoto(source:string(data["selfie"])).frame(maxWidth:.infinity).frame(height:260).clipShape(RoundedRectangle(cornerRadius:18))}
    Section{Text("Confronta viso, foto del profilo e codice scritto sul foglio. Il selfie verrà eliminato dopo la decisione.").font(.caption).foregroundStyle(.secondary);Button("Approva profilo"){form=NativeFormSpec(action:verificationAction232("approved"),context:data)}.padding(.vertical,8);Button("Rifiuta con un motivo",role:.destructive){form=NativeFormSpec(action:verificationAction232("rejected"),context:data)}.padding(.vertical,8)}
   }else{Section{Text(Catalog.display(data["status"]));Text(string(data["note"]));Text("Il selfie non è più conservato.").font(.caption).foregroundStyle(.secondary)}}
  }
 }.scrollContentBackground(.hidden).background(canvas).navigationTitle("Verifica profilo").task{await load()}.sheet(item:$form,onDismiss:{if completed{dismiss()}}){spec in NativeForm(store:store,spec:spec){completed=true}}}
 func load()async{do{data=try await store.request("/verification/"+rid);error=""}catch{self.error=error.localizedDescription}}
}
func verificationAction232(_ status:String)->Object {return ["title":status == "approved" ? "Approva profilo":"Rifiuta profilo","path":"/verification/{id}","method":"PUT","help":"Approva solo se viso e codice corrispondono. Per rifiutare, scrivi un motivo visibile all’utente.","fields":[["key":"confirmed_review","label":"Ho confrontato viso, foto del profilo e codice sul foglio","type":"bool","required":true],["key":"status","type":"hidden","source":"decision233","default":status],["key":"note","label":"Messaggio per l’utente (obbligatorio se rifiuti)","type":"long","required":status == "rejected"]]]}
