# Storage Distribution Summary

## Overview

This document describes the current storage distribution for the Raspberry Pi 4 NAS setup, including the migration of Prometheus TSDB from microSD to dedicated storage.

## Storage Architecture

### 1. Btrfs RAID 1 Array (`/mnt/nas`)
- **Type**: btrfs RAID 1 (mirrored)
- **Size**: 6TB usable (from two 6TB partitions)
- **Drives**: 
  - `/dev/sda1` (6TB partition from 8TB Seagate drive)
  - `/dev/sdb1` (6TB partition from 6TB Western Digital drive)
- **Mount Options**: `defaults,noatime,compress=zstd:3`
- **Purpose**: Primary NAS storage
- **Services**:
  - **Immich**: `/mnt/nas/immich/uploads` (photo/video library)
  - **Immich Postgres**: `/mnt/nas/immich/postgres` (database, optional)
  - **Immich Backups**: `/mnt/nas/immich-backups/` (backup files)

### 2. Ext4 Partition (`/mnt/storage`)
- **Type**: ext4 filesystem
- **Size**: 1.8TB (2GB used for swap)
- **Drive**: `/dev/sda2` (2TB partition from 8TB Seagate drive)
- **Purpose**: High-performance storage for write-heavy workloads
- **Services**:
  - **Prometheus TSDB**: `/mnt/storage/prometheus/` (time-series database with 15 days of retention)

### 3. MicroSD Card (`/`)
- **Type**: ext4 (root filesystem)
- **Size**: 59.5GB
- **Purpose**: Operating system and Docker runtime
- **Docker Volumes**: 
  - Grafana data (still on microSD via named volume)
  - Other Docker volumes as needed

## Prometheus TSDB Migration

### Migration Date
January 31, 2026

### Migration Details
- **From**: Docker named volume `monitoring_prometheus-data` (on microSD)
- **To**: Bind mount `/mnt/storage/prometheus` (on ext4 partition)
- **Data Size**: ~187MB (9 compacted blocks from Jan 25-31, 2026)
- **Time Series**: 6,395 active series
- **Targets**: 5 active scraping targets
- **Retention**: 15 days (default)

### Why Ext4 for Prometheus?
1. **Performance**: ext4 is faster for write-heavy workloads like TSDB
2. **Lower CPU Overhead**: No compression/checksumming overhead
3. **Data Characteristics**: Monitoring data is regenerable (unlike photos)
4. **Size**: 1.8TB is more than sufficient for long-term retention

### Migration Steps Completed
1. ✅ Created `/mnt/storage/prometheus` directory
2. ✅ Set ownership to UID 65534 (Prometheus user)
3. ✅ Copied all TSDB data (blocks, WAL, head chunks)
4. ✅ Updated `docker-compose.yml` to use bind mount
5. ✅ Verified all 9 blocks present and accessible
6. ✅ Confirmed Prometheus is writing new data

## Storage Strategy Rationale

### Btrfs RAID 1 for Immich
- **Redundancy**: Critical for irreplaceable photos/videos
- **Data Integrity**: Checksumming and self-healing
- **Compression**: Saves space on media files
- **RAID 1**: Mirrored across two drives for fault tolerance

### Ext4 for Prometheus
- **Performance**: Better for frequent small writes
- **Simplicity**: Lower CPU overhead on Raspberry Pi
- **Regenerable Data**: Monitoring data can be re-scraped if lost
- **Sufficient Space**: 1.8TB allows for extended retention periods

## Current Storage Usage

### Btrfs RAID 1 (`/mnt/nas`)
- **Total**: ~6TB usable
- **Immich**: Varies based on photo/video library size
- **Available**: Check with `df -h /mnt/nas`

### Ext4 Partition (`/mnt/storage`)
- **Total**: 1.8TB
- **Prometheus TSDB**: ~187MB (growing at ~30MB/day)
- **Swap**: 2GB
- **Available**: ~1.8TB - 2GB - 187MB = ~1.6TB free

### MicroSD Card
- **Total**: 59.5GB
- **Docker**: Grafana data and other volumes

## Future Considerations

### Potential Migrations
- **Grafana Data**: Could migrate to `/mnt/storage/grafana/` for better performance
- **Alertmanager**: Could use `/mnt/storage/alertmanager/` if needed

### Storage Expansion
- **2TB Unused Partition**: `/dev/sda2` has 2TB unused space that could be:
  - Used for additional services
  - Added to btrfs array (convert to 3-device RAID 1)
  - Used as separate backup location

## Verification Commands

### Check Storage Mounts
```bash
df -h | grep -E "nas|storage|mmcblk0"
```

### Verify Prometheus Storage
```bash
# Check mount point
docker inspect prometheus --format '{{ range .Mounts }}{{ if eq .Destination "/prometheus" }}{{ .Source }}{{ end }}{{ end }}'

# Check data size
sudo du -sh /mnt/storage/prometheus

# Verify blocks
docker exec prometheus ls -1 /prometheus/ | grep "^01" | wc -l
```

### Verify Btrfs RAID 1
```bash
# Check filesystem status
sudo btrfs filesystem show /mnt/nas

# Check usage
sudo btrfs filesystem usage /mnt/nas
```

## Notes

- Prometheus retention is set to 15 days (default)
- At current growth rate (~30MB/day), 15 days ≈ 450MB
- With 1.8TB available, retention could be extended significantly if needed
- hd-idle is configured to spin down drives after 30 minutes of inactivity
- btrfs compression (zstd:3) helps save space on media files

## Related Documentation

- Btrfs RAID 1 Setup: `/home/jenc/code/immich/docs/Btrfs-RAID-1-NAS-Setup.md`
- Prometheus Configuration: `/home/jenc/code/prometheus/docker-compose.yml`
