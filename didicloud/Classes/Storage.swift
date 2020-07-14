//
//  Storage.swift
//  CloudKit Todo
//
//  Created by Rodrigo Giglio on 29/06/20.
//  Copyright © 2020 Rodrigo Giglio. All rights reserved.
//

import Foundation
import CloudKit

public struct Storage {
    
    private static let forbidenAttributes = ["id", "record"]

    public static func newID() -> CKRecord.ID {
        return CKRecord.ID(recordName: UUID().uuidString)
    }
    
    /// Returns the current user icloud ID
    /// - Parameter completion: Result object containing the user icloud ID or an error
    public static func getUserRecordID(_ completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        CKContainer.default().fetchUserRecordID { (result, error) in
            
            if error != nil {
                completion(.failure(StorageError.cloudKitDataRetrieval))
                return
            }
            
            guard let result = result else {
                completion(.failure(StorageError.cloudKitNullReturn))
                return
            }
            
            completion(.success(result))
            
        }
    }
    
    
    /// Fetch all records of T owned by current user
    /// - Parameters:
    ///   - storageType: Which database to perform the query
    ///   - completion: Result object containing all fetched records or an error
    public static func fetchRecordsByUser<T: Storable>(storageType: StorageType = .privateStorage, _ completion: @escaping (Result<[T], Error>) -> Void) {
        
        getUserRecordID { (result) in
            switch result {
            case .success(let recordID):
                let query = CKQuery(
                    recordType: T.reference,
                    predicate: NSPredicate(format: "creatorUserRecordID == %@", recordID)
                )
                
                storageType.database.perform(query, inZoneWith: nil) {
                    results, error in
                    
                    if error != nil {
                        completion(.failure(StorageError.cloudKitDataRetrieval))
                        return
                    }
                    
                    guard let results = results else {
                        completion(.failure(StorageError.cloudKitNullReturn))
                        return
                    }
                    
                    var values: [T] = []
                    for record in results {
                        guard let value = try? T.parser.fromRecord(record) as? T else {
                            completion(.failure(StorageError.parsingFailure))
                            return
                        }
                        values.append(value)
                    }
                    
                    completion(.success(values))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public static func getAll<T: Storable>(storageType: StorageType = .privateStorage, _ completion: @escaping (Result<[T], Error>) -> Void) {
        
        let query = CKQuery(recordType: T.reference, predicate: NSPredicate(value: true))
        
        storageType.database.perform(query, inZoneWith: nil) {
            results, error in
            
            if error != nil {
                completion(.failure(StorageError.cloudKitDataRetrieval))
                return
            }
            
            guard let results = results else {
                completion(.failure(StorageError.cloudKitNullReturn))
                return
            }
            
            
            var values: [T] = []
            for record in results {
                guard let value = try? T.parser.fromRecord(record) as? T else {
                    completion(.failure(StorageError.parsingFailure))
                    return
                }
                values.append(value)
            }
            
            completion(.success(values))
        }
    }
    
    public static func get<T: Storable>(storageType: StorageType = .privateStorage, recordID: CKRecord.ID, _ completion: @escaping (Result<T, Error>) -> Void) {
                
        storageType.database.fetch(withRecordID: recordID) {
            result, error in
            
            if error != nil {
                completion(.failure(StorageError.cloudKitDataRetrieval))
                return
            }
            
            guard let record = result else {
                completion(.failure(StorageError.cloudKitNullReturn))
                return
            }
            
            guard let value = try? T.parser.fromRecord(record) as? T else {
                completion(.failure(StorageError.parsingFailure))
                return
            }
            
            completion(.success(value))
        }
    }
    
    public static func create<T: Storable>(storageType: StorageType = .privateStorage, _ storable: T, _  completion: @escaping (Result<T, Error>) -> Void) {
        
        guard let record = try? T.parser.toRecord(storable) else {
            return completion(.failure(StorageError.parsingFailure))
        }
                
        storageType.database.save(record) {
            (savedRecord, error) in
            
            if error != nil {
                completion(.failure(StorageError.cloudKitDataInsertion))
                return
            }
            
            guard let savedRecord = savedRecord else {
                completion(.failure(StorageError.cloudKitNullReturn))
                return
            }
            
            guard let value = try? T.parser.fromRecord(savedRecord) as? T else {
                completion(.failure(StorageError.parsingFailure))
                return
            }
            
            completion(.success(value))
        }
    }
    
    public static func update<T: Storable>(storageType: StorageType = .privateStorage, _ storable: T, _  completion: @escaping (Result<T, Error>) -> Void) {
        
        guard let record = try? T.parser.toRecord(storable) else {
            return completion(.failure(StorageError.parsingFailure))
        }
        
        storageType.database.save(record) {
            (savedRecord, error) in
            
            if error != nil {
                completion(.failure(StorageError.cloudKitDataUpdate))
                return
            }
            
            guard let savedRecord = savedRecord else {
                completion(.failure(StorageError.cloudKitDataRetrieval))
                return
            }
            
            guard let value = try? T.parser.fromRecord(savedRecord) as? T else {
                completion(.failure(StorageError.parsingFailure))
                return
            }
            
            completion(.success(value))
        }
    }
    
    public static func remove(storageType: StorageType = .privateStorage, _ recordID: CKRecord.ID, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
                
        storageType.database.delete(withRecordID: recordID) {
            (recordID, error) in
            
            if error != nil {
                completion(.failure(StorageError.cloudKitDataRemoval))
                return
            }
            
            guard let recordID = recordID else {
                completion(.failure(StorageError.cloudKitNullReturn))
                return
            }
            
            completion(.success(recordID))
        }
    }
}
