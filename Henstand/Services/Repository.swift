//
//  Repository.swift
//  Henstand
//
//  RTDB access under /users/{uid} (§14.2). Records are append-only with push-ids
//  (offline-safe merge); stock is never stored. keepSynced + offline persistence make
//  every branch readable instantly from cache. Codable ⇆ RTDB via a JSON bridge so
//  Decimal/Date/optionals round-trip uniformly.
//

import Foundation
import FirebaseDatabase

/// Records whose RTDB key IS their id (injected on decode; omitted from payload).
protocol Identified { var id: String { get set } }
extension Product: Identified {}
extension Batch: Identified {}
extension Sale: Identified {}
extension Reservation: Identified {}
extension DayRecord: Identified {}

final class Repository {
    let uid: String
    let root: DatabaseReference
    private var observedRefs: [DatabaseReference] = []

    init(uid: String) {
        self.uid = uid
        self.root = Database.database().reference().child("users").child(uid)
    }

    // MARK: JSON bridge

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    static func encode<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? encoder.encode(value),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return obj
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: Any) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let v = try? decoder.decode(type, from: data) else { return nil }
        return v
    }

    private static func parse<T: Decodable & Identified>(_ snap: DataSnapshot) -> [T] {
        var out: [T] = []
        for case let child as DataSnapshot in snap.children {
            guard let value = child.value, !(value is NSNull) else { continue }
            if var model = decode(T.self, from: value) {
                model.id = child.key
                out.append(model)
            }
        }
        return out
    }

    // MARK: Observers

    func start(products: @escaping ([Product]) -> Void,
               batches: @escaping ([Batch]) -> Void,
               sales: @escaping ([Sale]) -> Void,
               reservations: @escaping ([Reservation]) -> Void,
               days: @escaping ([DayRecord]) -> Void,
               settings: @escaping (Settings?) -> Void) {

        root.child("meta").child("schemaVersion").setValue(1)

        observeCollection("products", products)
        observeCollection("batches", batches)
        observeCollection("sales", sales)
        observeCollection("reservations", reservations)
        observeCollection("days", days)

        let sref = root.child("settings")
        sref.keepSynced(true)
        sref.observe(.value) { snap in
            if let value = snap.value, !(value is NSNull), let s = Repository.decode(Settings.self, from: value) {
                settings(s)
            } else {
                settings(nil)
            }
        }
        observedRefs.append(sref)
    }

    private func observeCollection<T: Decodable & Identified>(_ path: String, _ callback: @escaping ([T]) -> Void) {
        let ref = root.child(path)
        ref.keepSynced(true)
        ref.observe(.value) { snap in callback(Repository.parse(snap)) }
        observedRefs.append(ref)
    }

    func detach() {
        observedRefs.forEach { $0.removeAllObservers() }
        observedRefs.removeAll()
    }

    // MARK: Writes (append-only where possible)

    func addProduct(_ p: Product) { root.child("products").childByAutoId().setValue(Repository.encode(p)) }
    func updateProduct(_ p: Product) { root.child("products").child(p.id).setValue(Repository.encode(p)) }
    func deleteProduct(_ id: String) { root.child("products").child(id).removeValue() }

    func addBatch(_ b: Batch) { root.child("batches").childByAutoId().setValue(Repository.encode(b)) }
    func updateBatch(_ b: Batch) { root.child("batches").child(b.id).setValue(Repository.encode(b)) }

    func addSale(_ s: Sale) { root.child("sales").childByAutoId().setValue(Repository.encode(s)) }
    func setSaleVoided(_ id: String, _ voided: Bool) { root.child("sales").child(id).child("voided").setValue(voided) }

    func addReservation(_ r: Reservation) { root.child("reservations").childByAutoId().setValue(Repository.encode(r)) }
    func updateReservation(_ r: Reservation) { root.child("reservations").child(r.id).setValue(Repository.encode(r)) }
    func deleteReservation(_ id: String) { root.child("reservations").child(id).removeValue() }

    func writeSettings(_ s: Settings) { root.child("settings").setValue(Repository.encode(s)) }
    func writeDay(_ d: DayRecord) { root.child("days").child(d.date).setValue(Repository.encode(d)) }
}
