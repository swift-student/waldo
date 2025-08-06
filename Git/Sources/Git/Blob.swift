import Clibgit2
import Foundation

public extension Git {
    enum Blob {
        static func lookup(repo: OpaquePointer, oid: GitOID) throws(GitError) -> OpaquePointer {
            var blob: OpaquePointer?
            var oidCopy = oid
            
            let returnCode = git_blob_lookup(&blob, repo, &oidCopy)
            
            guard let blob else {
                throw .failedToLookupBlob(
                    Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
                )
            }
            
            return blob
        }
        
        static func data(_ blob: OpaquePointer) throws(GitError) -> Data {
            let rawPointer = git_blob_rawcontent(blob)
            let size = git_blob_rawsize(blob)
            
            guard let rawPointer = rawPointer else {
                throw .failedToLookupBlob(.init(code: .unknown))
            }
            
            return Data(bytes: rawPointer, count: Int(size))
        }
        
        static func free(_ blob: OpaquePointer) {
            git_blob_free(blob)
        }
    }
}