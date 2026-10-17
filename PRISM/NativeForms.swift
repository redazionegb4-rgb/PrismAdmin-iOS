import SwiftUI
import PhotosUI

struct NativeFormSpec:Identifiable {
 let id=UUID()
 let action:Object
 let context:Object
 var profile=false
}
@MainActor struct NativeForm:View {
 @ObservedObject var store:AdminStore
 let spec:NativeFormSpec
 let saved:() async -> Void
 @Environment(\.dismiss) private var dismiss
 @State private var values:Object=[:]
 @State private var error=""
 @State private var busy=false
 @State private var confirm=false
 @State private var photoItems:[PhotosPickerItem]=[]
 var fields:[Object]{objects(spec.action["fields"])}
 var body:some View {NavigationStack{Form {
  if let help=spec.action["help"] as? String {Text(help).font(.callout).foregroundStyle(.secondary)}
  if spec.action["danger"] as? Bool == true {Label("Verifica i dati prima di confermare questa operazione.",systemImage:"exclamationmark.shield").foregroundStyle(.orange)}
  ForEach(Array(fields.enumerated()),id:\.offset){_,field in input(field)}
  if !error.isEmpty{Text(error).foregroundStyle(.red)}
  if fields.isEmpty{Text("Conferma per eseguire: \(string(spec.action["title"])).")}
 }.scrollContentBackground(.hidden).background(canvas).navigationTitle(string(spec.action["title"])).navigationBarTitleDisplayMode(.inline).toolbar {
  ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}.disabled(busy)}
  ToolbarItem(placement:.confirmationAction){Button{if spec.action["danger"] as? Bool == true{confirm=true}else{Task{await submit()}}}label:{if busy{ProgressView()}else{Text("Conferma").bold()}}.disabled(busy)}
 }.interactiveDismissDisabled(busy).confirmationDialog("Confermi l’operazione?",isPresented:$confirm,titleVisibility:.visible){Button("Conferma",role:.destructive){Task{await submit()}}}.onAppear{seed()}.onChange(of:photoItems){items in Task{await upload(items)}}}
 }
 func seed(){guard values.isEmpty else{return};for f in fields{let key=string(f["key"]);let raw=value(spec.context,string(f["source"] ?? key)) ?? f["default"] ?? "";values[key]=raw};if spec.profile{values["revision"]=spec.context["profile_revision"]}}
 func text(_ key:String)->Binding<String>{Binding(get:{string(values[key])},set:{values[key]=$0})}
 func bool(_ key:String)->Binding<Bool>{Binding(get:{values[key] as? Bool ?? false},set:{values[key]=$0})}
 func selected(_ key:String,_ community:Bool=false)->[String]{if community{return string(values[key]).components(separatedBy:"·").map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty}};return values[key] as? [String] ?? []}
 @ViewBuilder func input(_ f:Object)->some View {
  let key=string(f["key"]),type=string(f["type"]),label=string(f["label"])
  if type=="hidden"{}else if key.hasPrefix("availability.") && key != "availability.kind" && string(values["availability.kind"])=="none"{}else if type=="bool"{Toggle(label,isOn:bool(key))}
  else if type=="password"{SecureField(label,text:text(key)).textContentType(.newPassword)}
  else if type=="photos"{Section(label){
   let photos=values[key] as? [String] ?? []
   ForEach(Array(photos.enumerated()),id:\.offset){i,p in HStack{NativePhoto(source:p).frame(width:68,height:84).clipShape(RoundedRectangle(cornerRadius:12));VStack(alignment:.leading){Text(i==0 ? "Principale":"Foto \(i+1)");if i>0{Button("Usa come principale"){var copy=photos;copy.insert(copy.remove(at:i),at:0);values[key]=copy}.font(.caption)}};Spacer();Button(role:.destructive){var copy=photos;copy.remove(at:i);values[key]=copy}label:{Image(systemName:"trash")}}}
   PhotosPicker(selection:$photoItems,maxSelectionCount:max(1,6-photos.count),matching:.images){Label("Aggiungi foto",systemImage:"photo.badge.plus")}.disabled(busy || photos.count>=6)
   Text("Fino a 6 foto. Le nuove foto passano dalla verifica.").font(.caption).foregroundStyle(.secondary)
  }}
  else if type=="multi" || type=="community"{Section(label){
   let options=objects(f["options"]);let custom=selected(key,type=="community").filter{v in !options.contains{string($0["value"])==v}};let all=options+custom.map{["value":$0,"label":$0]}
   ForEach(all,id:\.optionValue){o in let v=string(o["value"]),chosen=selected(key,type=="community").contains(v);Button{var items=selected(key,type=="community");if chosen{items.removeAll{$0==v}}else{if type=="community" && items.count>=3{error="Puoi selezionare fino a tre community.";return};items.append(v)};if type=="community"{values[key]=items.joined(separator:" · ")}else{values[key]=items}}label:{HStack{Text(string(o["label"])).foregroundStyle(.primary);Spacer();Image(systemName:chosen ? "checkmark.circle.fill":"circle").foregroundStyle(chosen ? gold:Color.secondary)}}
   }
  }}
  else if type=="date" || type=="datetime"{
   DatePicker(label,selection:Binding(get:{let raw=string(values[key]);if type=="date"{let d=DateFormatter();d.dateFormat="yyyy-MM-dd";d.timeZone=TimeZone(secondsFromGMT:0);return d.date(from:raw) ?? Date(timeIntervalSince1970:631152000)};return isoDate(raw) ?? Date().addingTimeInterval(3600)},set:{date in if type=="date"{let d=DateFormatter();d.dateFormat="yyyy-MM-dd";d.timeZone=TimeZone(secondsFromGMT:0);values[key]=d.string(from:date)}else{values[key]=ISO8601DateFormatter().string(from:date)}}),displayedComponents:type=="date" ? [.date]:[.date,.hourAndMinute])
  }
  else if type=="select"{Picker(label,selection:text(key)){ForEach(objects(f["options"]),id:\.optionValue){o in Text(string(o["label"])).tag(string(o["value"]))}}}
  else if type=="choice"{Section(label){TextField("Non indicato",text:text(key));ScrollView(.horizontal){HStack{ForEach(objects(f["options"]),id:\.optionValue){o in Button(string(o["label"])){values[key]=string(o["value"])}.buttonStyle(.bordered)}}}}}
  else{VStack(alignment:.leading,spacing:8){Text(label).font(.caption).foregroundStyle(.secondary);TextField(label,text:text(key),axis:type=="long" ? .vertical:.horizontal).lineLimit(type=="long" ? 3...8:1...1).keyboardType(["int","number"].contains(type) ? .numberPad:.default).textInputAutocapitalization(key.contains("instagram") || key.contains("facebook") || key.contains("email") || key.contains("url") ? .never:.sentences).autocorrectionDisabled(key.contains("url") || key.contains("email"))}}
 }
 func submit()async{
  guard !busy else{return};error="";var body:Object=[:]
  for field in fields{
   let key=string(field["key"]),type=string(field["type"]);var v:Any=values[key] ?? field["default"] ?? ""
   if type=="int"{guard let n=Int(string(v)) else{error="Inserisci un numero per \(string(field["label"])).";return};v=n}
   if type=="datetime" && string(v).isEmpty{v=ISO8601DateFormatter().string(from:Date().addingTimeInterval(3600))}
   if field["required"] as? Bool == true && (type=="bool" ? (v as? Bool != true):string(v).trimmingCharacters(in:.whitespacesAndNewlines).isEmpty){error="Compila: \(string(field["label"])).";return}
   put(&body,key,v)
  }
  if spec.profile{body["revision"]=spec.context["profile_revision"] ?? "";if string(value(body,"availability.kind"))=="none"{body["availability"]=NSNull()}}
  let path=string(spec.action["path"]).replacingOccurrences(of:"{id}",with:string(spec.context["id"]))
  busy=true;defer{busy=false}
  do{_=try await store.request(path,method:string(spec.action["method"]),body:body);store.didMutate();await saved();dismiss();Task{await store.refreshCounts()}}catch{self.error=error.localizedDescription}
 }
 func upload(_ items:[PhotosPickerItem])async{
  guard !busy,!items.isEmpty else{return};busy=true;defer{busy=false;photoItems=[]}
  var photos=values["profile.extra.photos"] as? [String] ?? []
  do{for item in items{guard photos.count<6 else{break};guard let bytes=try await item.loadTransferable(type:Data.self),let image=thumbnail(bytes),let jpeg=image.jpegData(compressionQuality:0.9)else{throw AdminFailure(message:"Non riesco a leggere questa foto. Scegli un’altra immagine.")};let result=try await store.request("/profile-photo",method:"POST",bytes:jpeg);guard let photo=result["photo"] as? String else{throw AdminFailure(message:"Caricamento foto non riuscito.")};photos.append(photo);values["profile.extra.photos"]=photos}}catch{self.error=error.localizedDescription}
 }
}
