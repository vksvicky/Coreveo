# Full Disk Access Detection Strategy

## Overview
FDA detection must work reliably across:
- **Intel and Apple Silicon** (x86_64 and ARM64)
- **macOS 14+** (with varying permission behaviors)
- **Sandboxed and non-sandboxed** apps
- **Systems with different user data** (some users may not have Mail/Calendar data)

## Detection Approach

### Priority Levels

#### 1. PRIMARY Paths (Most Reliable)
These paths require FDA on most systems and are the first choice:
- `~/Library/Mail` - Most reliable, exists on most systems
- `~/Library/Calendars` - Also reliable
- `~/Library/Messages` - Messages data

**Why Primary?**
- Consistently require FDA across Intel/Silicon
- Work in sandboxed apps (test sandboxed home directory)
- Exist on most user systems

#### 2. FALLBACK Paths
Used if primary paths don't exist:
- `~/Library/Safari` - May not exist in sandbox
- `~/Library/Safari/History.db` - Specific Safari file
- `~/Library/Application Support/com.apple.TCC/TCC.db` - User TCC database

**Why Fallback?**
- May not exist on all systems
- Safari specifically may not exist in sandbox container
- Still reliable if they do exist

#### 3. SYSTEM Paths (Not Recommended)
These are tested last as behavior varies:
- `/Library/Application Support/com.apple.TCC/TCC.db` - System TCC
- System directories

**Why Not Recommended?**
- May not require FDA on some macOS versions
- Inconsistent behavior across systems

## Implementation

### Algorithm
1. Test primary paths in order
2. If path exists and access is denied → FDA not granted ✅
3. If path exists and access succeeds → FDA granted ✅
4. If path doesn't exist → Skip to next path
5. If all primary paths unavailable → Try fallbacks
6. If no paths can be tested → Assume FDA NOT granted (safe default)

### Error Handling
- **NSCocoaErrorDomain 257** (Permission Denied) → FDA NOT granted
- **Other errors** → Skip to next path
- **No testable paths** → Return false (safe default)

## Compatibility Matrix

| System | Primary Paths | Fallback Paths | Detection |
|--------|--------------|----------------|-----------|
| M4 Sandboxed | Mail ✅, Calendars ✅ | Safari ❌ | ✅ Reliable |
| Intel Sandboxed | Mail ✅, Calendars ✅ | Safari ❌ | ✅ Reliable |
| M4 Non-sandboxed | Mail ✅, Calendars ✅ | Safari ✅ | ✅ Reliable |
| Fresh System | Messages ✅ | TCC DB ✅ | ✅ Has fallbacks |

## Testing

### Diagnostic Test
`FDADiagnosticTests.testWhatRequiresFDA()` verifies:
- Which paths exist on the system
- Which paths require FDA
- System architecture (Intel vs Silicon)
- macOS version
- Sandbox status

### Running Diagnostics
1. Disable FDA in System Settings
2. Run diagnostic test
3. Check console for:
   - PRIMARY paths that work ✅
   - FALLBACK paths available
   - System information

## Logging

Enable verbose logging with `NSLog` to see:
```
[PermissionManager] Checking FDA permission...
[PermissionManager] Sandbox home: /Users/.../Containers/.../Data
[PermissionManager]   Testing: .../Library/Mail
[PermissionManager]   → ❌ PERMISSION DENIED - FDA NOT GRANTED
```

## Troubleshooting

### False Positives
If FDA shows as granted when it's not:
- Check which path returned success
- Verify that path actually requires FDA
- Run diagnostic test to confirm

### False Negatives
If FDA shows as not granted when it is:
- Verify primary paths exist
- Check console logs for errors
- May need to add more fallback paths

## Future Improvements

1. **Add more primary paths** as discovered across different systems
2. **Cache detection results** for 30 seconds to avoid repeated checks
3. **Test on more systems** (Intel macs, older macOS versions)
4. **Monitor macOS updates** for changes in FDA behavior

