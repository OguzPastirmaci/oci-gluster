# Gluster on OCI HPC
Several open-source file systems are available for customers to use. These file systems, include Lustre, GlusterFS, and BeeGFS file systems.

A Parallel File System distributes file data across multiple servers and provides concurrent access by multiple tasks of a parallel application. Used in high-performance computing (HPC) environments, a Parallel File System delivers high-performance access to large data sets.

A Parallel File System cluster includes nodes designated as one or more clients, plus management servers, storage servers, and metadata servers. Storage servers hold file data, while metadata servers store statistics, attributes, data file-handles, directory entries, and other metadata. Clients run applications that use the file system by sending requests to the servers over the network.

We hope this default configuration serves as a baseline you can refer to when designing and sizing a PVFS architecture on Azure that meets your needs. We also show how to install the tools we used for performance testing, so you can try your own comparison tests. The test scripts are available from the az-cat/HPC-Filesystems repository on GitHub.

In this example we use Gluster which is a scalable, distributed file system that aggregates disk storage resources from multiple servers into a single global namespace.

## Advantages of Gluster
* Scales to several petabytes
* Handles thousands of clients
* POSIX compatible
* Uses commodity hardware
* Can use any ondisk filesystem that supports extended attributes
* Accessible using industry standard protocols like NFS and SMB
* Provides replication, quotas, geo-replication, snapshots and bitrot detection
* Allows optimization for different workloads
* Open Source

[arch]: https://github.com/oci-hpc/oci-hpc-gluster/blob/master/images/640px-GlusterFS_Architecture.png

Enterprises can scale capacity, performance, and availability on demand, with no vendor lock-in, across on-premise, public cloud, and hybrid environments. Gluster is used in production at thousands of enterprises spanning media, healthcare, government, education, web 2.0, and financial services.
