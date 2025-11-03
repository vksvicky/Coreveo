# Coreveo Development Roadmap

**Coreveo** - "Core" + "reveo" (reveal) → reveal what's inside your Mac

A comprehensive Mac system monitoring app with features inspired by Dashboard Pro, Performance Test Benchmark, Monit, and iStats, plus unique differentiating capabilities.

## 🎯 Project Overview

Coreveo aims to be the ultimate Mac system monitoring solution with:
- **Comprehensive System Monitoring**: CPU, Memory, Disk, Network, Battery, Temperature, Fans
- **Flexible Display Modes**: Dock App, Menu Bar, Desktop Widgets, Notification Center
- **Unique Features**: AI-powered insights, benchmarking, energy analysis, security monitoring
- **Privacy-First Design**: All data processing happens locally

## 🗺️ Development Phases

### **PHASE 1: Foundation & Core Monitoring**  
_(Priorities: P0 = critical, P1 = high, P2 = medium, P3 = low)_
*Essential system monitoring capabilities*

- [ ] **Project Setup**
  - [x] Set up Xcode project with SwiftUI architecture
  - [x] Implement basic project structure and dependencies
  - [ ] Set up IOKit and Core Foundation integration

- [ ] **CPU Monitoring** (P1) [WIP]
  - [x] Real-time CPU usage per core
  - [ ] CPU temperature monitoring [WIP]
  - [ ] Historical CPU load graphs
  - [ ] Top processes by CPU consumption

- [ ] **Memory Monitoring** (P1)
  - [ ] Current RAM usage breakdown (active, wired, compressed, free)
  - [ ] Memory pressure indicators
  - [ ] Swap usage and activity
  - [ ] Top memory-consuming applications

- [ ] **Disk Monitoring** (P2)
  - [ ] Storage capacity and usage statistics
  - [ ] Real-time disk I/O performance (read/write speeds)
  - [x] Basic S.M.A.R.T. disk health monitoring (✅ Implemented)
    - [x] Disk discovery and enumeration
    - [x] Temperature monitoring for SSDs/HDDs
    - [x] Health status display (Healthy/Warning/Critical)
    - [x] Power-on hours tracking
    - [x] Wear level monitoring (SSDs)
    - [x] Full Disk Access permission integration
    - [x] User-friendly FDA requirement messaging
    - [x] Dedicated Disk Health settings view
  - [ ] **Advanced S.M.A.R.T. Monitoring** (see detailed section below)

- [ ] **Network Monitoring** (P3)
  - [ ] Real-time upload/download speeds
  - [ ] Public and local IP addresses
  - [ ] Wi-Fi signal strength and network details
  - [ ] Network interface status

- [ ] **Battery Monitoring** (MacBooks) (P2)
  - [ ] Current charge level and time remaining
  - [ ] Battery health status and cycle count
  - [ ] Power usage statistics
  - [ ] Temperature readings

- [ ] **Temperature & Fan Control** (P2)
  - [ ] CPU, GPU, and system temperature readings
  - [ ] Per‑sensor temperature list (efficiency/performance cores, GPU clusters, battery, SSD, airflow, I/O, power, proximity) [WIP]
  - [ ] Fan speed monitoring (multi‑fan), dashboard average + detail per fan [WIP]
  - [ ] Thermal throttling detection
  - [ ] Overheating alerts

#### Sensor Infrastructure & Mapping (to match TG Pro depth)
- [x] IOReport pipeline (Apple Silicon + Intel)
  - [x] Channel enumeration and unit decoding (abstraction + tests)
  - [ ] Group subscriptions (Thermal, Energy Model, GPU groups) with throttled sampling
- [x] Versioned Sensor Catalog (per‑model/OS mapping DB)
  - [x] Schema v1 and loader
  - [ ] Per‑model/OS key/channel → name/unit/domain mapping
  - [ ] Unknown sensor quarantine and migration rules
- [x] Normalization & Calibration
  - [x] Per‑sensor transforms (scale/offset), sanity filters, smoothing
  - [ ] De‑dup/aggregate domains (e.g., GPU clusters → GPU temp)
- [x] Device/OS Detection & Routing
  - [x] Platform and SoC/GPU family probe (profile model)
  - [x] Source selection hierarchy (IOReport > IOHWSensor > SMC > powermetrics)
- [x] Privileged Helper (daemon)
  - [x] Signed launchd helper + XPC API (scaffold)
  - [ ] Permissions gating and watchdog
- [x] Fallback Collectors
  - [x] `powermetrics` parser (rate‑limited)
  - [ ] SMART/NVMe readers
- [x] Update Delivery
  - [x] Remote config for mapping DB (local override)
  - [ ] Feature flags/kill switches per sensor group
- [x] Telemetry
  - [x] Structured logs for missing/renamed channels and anomalies
  - [ ] Opt‑in anonymous coverage metrics
- [ ] Testing Matrix
  - [ ] Golden IOReport recordings per model/OS
  - [ ] Regression tests for presence/units
  - [ ] Fixtures for offline tests

#### Comprehensive S.M.A.R.T. Disk Health Monitoring
*Detailed disk health tracking and predictive failure analysis*

**Phase 1A: Core Data Collection** (P2) - [Basic implementation ✅]
- [x] Raw SMART attribute reading - Read all available SMART attributes from drives
- [x] SMART status verification - Check overall pass/fail status  
- [x] Temperature monitoring - Track current drive temperature
- [x] Power-on hours tracking - Monitor total operational time
- [ ] Power cycle count - Track number of power cycles
- [ ] Reallocated sector monitoring - Track remapped bad sectors
- [ ] Pending sector detection - Identify sectors awaiting reallocation
- [ ] Uncorrectable error tracking - Monitor unrecoverable read/write errors
- [ ] CRC error count - Track data transfer errors
- [ ] Seek error rate monitoring - Track head positioning errors (HDD)
- [ ] Spin retry count - Monitor spin-up failures (HDD)
- [ ] Start/stop cycle count - Track spindle start/stop cycles (HDD)
- [ ] Load/unload cycle count - Monitor head parking operations (HDD)
- [x] SSD wear leveling - Track flash cell usage distribution
- [ ] Total bytes written/read - Monitor SSD usage metrics
- [x] Available spare blocks - Track SSD reserve capacity
- [ ] Media wearout indicator - Monitor SSD lifespan percentage
- [ ] Program fail count - Track SSD write failures
- [ ] Erase fail count - Track SSD erase operation failures
- [ ] TRIM command support detection - Verify SSD optimization capability

**Phase 1B: Display & Visualization** (P2) - [Basic implementation ✅]
- [x] Real-time attribute display - Show current SMART values
- [x] Health score calculation - Overall drive health percentage
- [x] Traffic light indicators - Red/yellow/green status
- [x] Dashboard view - Multi-drive overview
- [ ] Detailed attribute view - Show all raw values
- [ ] Color-coded warnings - Enhanced visual severity indicators
- [ ] Graphical trend charts - Visualize attribute history
- [ ] Temperature graphs - Plot temperature over time
- [ ] Comparison view - Compare multiple drives
- [ ] Predicted lifespan display - Estimated remaining life

**Phase 2A: Logging & History** (P2)
- [ ] Historical data logging - Store SMART values over time
- [ ] Attribute trend analysis - Track how values change
- [ ] Error log parsing - Read and interpret drive error logs
- [ ] Self-test log monitoring - Track results of drive self-tests
- [ ] Event timestamp recording - Log when changes occur
- [ ] Database storage - Store long-term SMART history (SQLite)
- [ ] CSV/JSON export - Export data for external analysis
- [ ] Statistical summaries - Generate health reports
- [ ] Comparative baseline tracking - Compare against initial values

**Phase 2B: System Integration** (P1)
- [x] Multi-drive monitoring - Track all connected drives simultaneously
- [x] Internal drive monitoring - Monitor built-in storage
- [ ] External drive monitoring - Track USB/Thunderbolt drives
- [ ] RAID array monitoring - Individual disk monitoring in arrays
- [x] NVMe-specific monitoring - NVMe health attributes
- [ ] HDD-specific monitoring - Mechanical drive attributes (seek error, spin retry)
- [x] SSD-specific monitoring - Flash-specific metrics
- [ ] Launch at startup - Automatic monitoring on boot
- [ ] Background daemon operation - Run without GUI
- [ ] Low resource usage - Minimal system impact
- [x] Permission handling - Proper FDA access management

**Phase 3A: Testing Features** (P3)
- [ ] Short self-test execution - Run quick drive diagnostics
- [ ] Extended self-test execution - Run comprehensive diagnostics
- [ ] Conveyance self-test - Test for shipping damage
- [ ] Selective self-test - Test specific drive regions
- [ ] Background scan monitoring - Track automatic drive scans
- [ ] Test scheduling - Automate regular self-tests
- [ ] Test result verification - Parse and report test outcomes
- [ ] Offline data collection - Enable background SMART updates

**Phase 3B: Alert & Notification** (P2)
- [ ] Threshold violation alerts - Warn when attributes exceed limits
- [ ] Temperature alerts - Notify on overheating
- [ ] Rapid degradation detection - Alert on quick attribute changes
- [ ] Failure prediction warnings - Warn of imminent drive failure
- [ ] macOS notification center integration - System notifications
- [ ] Sound/audio alerts - Audible warnings
- [ ] Menu bar status indicators - Visual health indicators
- [ ] Badge notifications - App icon badges for warnings
- [ ] Scheduled health reports - Regular status summaries
- [ ] Email alerts - Send notifications via email (optional)
- [ ] SMS/push notifications - Mobile alerts (optional)
- [ ] Webhook integration - Third-party service notifications

**Phase 3C: Advanced Analysis** (P3)
- [ ] Predictive failure analysis - ML-based failure prediction
- [ ] Anomaly detection - Identify unusual patterns
- [ ] Correlation analysis - Link multiple attribute changes
- [ ] Benchmark comparison - Compare against drive model norms
- [ ] Age-adjusted thresholds - Account for expected wear
- [ ] Environmental factor tracking - Correlate with temperature/humidity
- [ ] Performance impact analysis - Link health to performance
- [ ] Warranty status tracking - Link to drive age/warranty

**Phase 4A: Automation** (P3)
- [ ] Scheduled monitoring - Regular automatic checks
- [ ] launchd integration - macOS service scheduling
- [ ] Script execution on events - Trigger actions on alerts
- [ ] Automatic backup triggers - Start backups on warnings
- [ ] Safe mode on critical failure - Protect data on imminent failure
- [ ] Log rotation - Manage log file sizes
- [ ] Auto-update SMART database - Keep drive definitions current

**Phase 4B: Reporting** (P3)
- [ ] PDF report generation - Formatted health reports
- [ ] HTML report export - Web-viewable reports
- [ ] Plain text summaries - Simple status reports
- [ ] Compliance reporting - Enterprise audit trails
- [ ] Executive summaries - High-level overviews

**Phase 4C: Configuration & Customization** (P3)
- [ ] Custom threshold setting - Adjust warning levels
- [ ] Monitoring interval configuration - Set check frequency
- [ ] Attribute selection - Choose which attributes to track
- [ ] Alert preference customization - Configure notification types
- [ ] Display preference settings - Customize interface
- [ ] Profile management - Different settings per drive type
- [ ] Import/export configurations - Share settings

**Phase 5A: Data Protection & Security** (P1)
- [x] Read-only monitoring - Never write to drives
- [x] Safe mode operation - Prevent accidental damage
- [ ] Encrypted log storage - Secure sensitive data
- [ ] Access logging - Track who viewed data
- [ ] Privacy mode - Anonymize serial numbers in reports

**Implementation Notes:**
- Basic S.M.A.R.T. monitoring foundation implemented (✅)
- Requires `smartctl` (Homebrew: `brew install smartmontools`)
- Full Disk Access permission required for all operations
- Test suite implemented using TDD approach
- See `docs/SMART_MONITORING_IMPLEMENTATION.md` for technical details

- [ ] **Process Management** (P3)
  - [ ] Running processes with resource usage
  - [ ] Process termination capabilities
  - [ ] Process priority management
  - [ ] Background app activity monitoring

### **PHASE 2: Display Modes**  
_(P0-P2 depending on permutation; see priorities below)_
*Flexible user interface options*

- [ ] **Dock App Mode** (P1)
  - [ ] Full-featured application with comprehensive dashboard
  - [ ] Resizable window with multiple tabs
  - [ ] Deep-dive analytics and historical data
  - [ ] Complete system control and management

- [ ] **Menu Bar Integration** (P0)
  - [x] Compact menu bar icon with real-time metrics
  - [x] Dropdown with key statistics
  - [x] Preference to show/hide menu bar item
  - [ ] Quick access to alerts and notifications
  - [ ] Minimal resource footprint

- [ ] **Desktop Widgets** (P2)
  - [ ] Floating, resizable, movable widgets on desktop
  - [ ] Multiple widget types (CPU, Memory, Network, Temperature)
  - [ ] Customizable transparency and styling
  - [ ] Always-on-top option

- [ ] **Notification Center Widgets** (P3)
  - [ ] Integration with macOS Notification Center
  - [ ] Quick stats in Today view
  - [ ] Swipe gestures for more details
  - [ ] System status at a glance

- [ ] **Flexible Combinations** (P1)
  - [ ] Hybrid mode combining any of the above modes
  - [ ] Context-aware switching based on activity
  - [ ] Profile-based modes for different user profiles
  - [ ] Synchronized data across all modes
  - [ ] Supported permutations (user-selectable)
    - [ ] Dock only
    - [ ] Menu Bar only (P0)
    - [ ] Widgets only (P2)
    - [ ] Dock + Menu Bar (P1)
    - [ ] Dock + Widgets (P2)
    - [ ] Menu Bar + Widgets (P2)
    - [ ] Dock + Menu Bar + Widgets (all) (P2)
  - [ ] Single source of truth for monitoring data shared across modes
  - [ ] Unified preference to enable/disable each mode at runtime

### **PHASE 3: Unique Features** (P3 overall)
*Differentiating capabilities*

- [ ] **Adaptive Performance Intelligence**
  - [ ] Smart alerts that learn usage patterns
  - [ ] Performance predictions based on trends
  - [ ] Usage pattern analysis and insights
  - [ ] Resource bottleneck identification

- [ ] **Comprehensive Benchmarking Suite**
  - [ ] Real-time benchmarking without workflow interruption
  - [ ] Comparative analysis against similar Mac models
  - [ ] Performance regression detection
  - [ ] Custom benchmark tests for specific use cases

- [ ] **Energy Impact Analysis**
  - [ ] Detailed app energy profiling
  - [ ] Battery life optimization recommendations
  - [ ] Power efficiency scoring for apps and processes
  - [ ] Sustainable computing insights

- [ ] **Advanced Security Monitoring**
  - [ ] Network security scanner for unusual activity
  - [ ] Process anomaly detection for suspicious processes
  - [ ] File system integrity monitoring
  - [ ] Privacy dashboard for app data access

- [ ] **Hardware Health Predictions**
  - [x] Basic S.M.A.R.T. disk health monitoring (✅ Foundation complete)
  - [ ] Component failure prediction using S.M.A.R.T. data (ML-based)
  - [ ] Upgrade recommendations based on usage patterns
  - [ ] Performance optimization suggestions
  - [ ] Maintenance scheduling reminders
  - *Note: See "Comprehensive S.M.A.R.T. Disk Health Monitoring" in Phase 1 for detailed roadmap*

- [ ] **Customizable Dashboard Engine**
  - [ ] Drag-and-drop widget interface
  - [ ] Multiple dashboard profiles (work, gaming, development)
  - [ ] Widget marketplace for community-created widgets
  - [ ] Automated layout arrangements based on usage

### **PHASE 4: Advanced Features** (P3)
*Specialized functionality*

- [ ] **Performance Gaming Mode**
  - [ ] Real-time FPS monitoring for games
  - [ ] Gaming performance optimization
  - [ ] Resource allocation for gaming applications
  - [ ] Gaming-specific alerts and recommendations

- [ ] **Developer Tools Integration**
  - [ ] Xcode integration for build time monitoring
  - [ ] Docker container resource usage tracking
  - [ ] Terminal integration for power users
  - [ ] Development workflow optimization

- [ ] **Accessibility Features**
  - [ ] Voice announcements for system status
  - [ ] High contrast mode for visual impairments
  - [ ] Large text options and scalable interface
  - [ ] Keyboard navigation support

- [ ] **Data Export & Analytics**
  - [ ] Performance report generation
  - [ ] Data export to CSV, JSON, and other formats
  - [ ] Optional cloud backup of performance data
  - [ ] REST API for third-party integrations

### **PHASE 5: Polish & Launch**  
_(mixed priorities, core items marked P0/P1)_
*Production readiness*

- [ ] **Settings & Preferences** (P0)
  - [x] Comprehensive settings interface
    - [x] General tab
      - [ ] Launch at Login (P1)
        - [x] UI: toggle present in General tab
        - [ ] Functionality: register/unregister app at login via SMAppService
      - [ ] Start Monitoring on Launch (P1)
        - [x] UI: toggle present in General tab
        - [ ] Functionality: auto-start `SystemMonitor` on app launch when enabled
      - [ ] Show Menu Bar Item (P0)
        - [x] UI: toggle present in General tab
        - [ ] Functionality: show/hide menu bar extra dynamically
      - [ ] Refresh Interval (P0)
        - [x] UI: slider (0.5s–5s) + value label
        - [x] Functionality: apply interval to monitoring timer
      - [ ] Temperature Units (P2)
        - [x] UI: segmented control (Celsius/Fahrenheit)
        - [ ] Functionality: convert/format temperatures based on selection
    - [x] Appearance tab
      - [x] Theme selection (System/Light/Dark)
      - [x] Accent/appearance polish
    - [x] Permissions tab
      - [x] Accessibility status + actions
      - [x] Full Disk Access status + actions
      - [x] Open System Settings CTAs
  - [x] User preference management (AppStorage) (P0)
  - [x] Theme and appearance customization (ThemeManager)
  - [ ] Notification preferences

- [ ] **Help & Documentation**
  - [x] In‑app Help window (menu command)
  - [x] Help content (`docs/HELP.md`)
  - [ ] User guide and screenshots
  - [ ] Markdown viewer polish
    - [x] Native markdown rendering in Help window
    - [x] Bundled `HELP.md` lookup across root/docs/full-scan
    - [x] Pluggable renderer abstraction + tests
    - [ ] Optional package renderer integration (`swiftui-markdown`)
    - [ ] Styling theme parity (headings, lists, code blocks)
    - [ ] Link handling and external URL opening
    - [ ] In‑app anchors/table of contents (if content grows)

- [ ] **Data Management** (P2)
  - [ ] Data persistence and historical tracking
  - [ ] Efficient data storage and retrieval
  - [ ] Data cleanup and maintenance
  - [ ] Backup and restore functionality

- [ ] **Performance & Optimization** (P2)
  - [ ] Performance optimization and memory management
  - [ ] Battery usage optimization
  - [ ] CPU overhead minimization
  - [ ] Resource usage monitoring

- [ ] **Quality Assurance** (P1)
  - [ ] Comprehensive error handling and logging
  - [x] Automated tests (theme mapping, help window, prefs round‑trip, monitor lifecycle, per‑core CPU, markdown renderer)
  - [ ] Performance testing and benchmarking
  - [ ] User acceptance testing

- [ ] **Distribution Preparation**
  - [ ] App signing and code signing
  - [ ] App Store preparation and submission
  - [ ] Documentation and user guides
  - [ ] Marketing materials and screenshots

### **PHASE 6: Future Enhancements**
*Post-launch features*

- [ ] **Extensibility**
  - [ ] Plugin system for third-party extensions
  - [ ] Widget marketplace for community widgets
  - [ ] API for custom integrations
  - [ ] Developer documentation and SDK

- [ ] **Cloud Features** (Optional)
  - [ ] Cloud sync for performance data
  - [ ] Cross-device synchronization
  - [ ] Remote monitoring capabilities
  - [ ] Cloud-based analytics

- [ ] **Advanced Integrations**
  - [ ] REST API for third-party integrations
  - [ ] Webhook support for external services
  - [ ] Integration with popular Mac apps
  - [ ] Enterprise features and management

- [ ] **Community Features**
  - [ ] Widget marketplace
  - [ ] Community forums and support
  - [ ] User-generated content sharing
  - [ ] Beta testing program

## 🎨 Core Features Summary

### **Standard System Monitoring**
- System Overview (macOS version, hardware specs, uptime)
- CPU Monitoring (per-core usage, temperature, processes)
- Memory Monitoring (RAM usage, pressure, swap, top processes)
- Storage Monitoring (capacity, I/O, comprehensive S.M.A.R.T. health tracking, temperature, wear leveling)
- Network Monitoring (speed, IP addresses, interfaces)
- Battery Monitoring (charge, health, cycles, power usage)
- Temperature & Fan Control (monitoring and manual control)
- Process Management (monitoring and termination)

### **Unique Differentiating Features**
- Adaptive Performance Intelligence
- Comprehensive Benchmarking Suite
- Energy Impact Analysis
- Advanced Security Monitoring
- Hardware Health Predictions
- Customizable Dashboard Engine
- Performance Gaming Mode
- Developer Tools Integration

### **Flexible Display Options**
- Dock App Mode (full-featured application)
- Menu Bar Integration (compact, always accessible)
- Desktop Widgets (floating, customizable)
- Notification Center Widgets (quick stats)
- Flexible Combinations (any mix of the above)

## 🏗️ Technical Architecture

### **Technology Stack**
- **Primary Language**: Swift (native compilation, optimized for Apple Silicon/Intel)
- **UI Framework**: SwiftUI (modern, declarative UI with efficient rendering)
- **System Integration**: AppKit (menu bar, desktop widgets, system permissions)
- **System APIs**: IOKit and Core Foundation (direct hardware monitoring)
- **Target Platform**: macOS 14+ (Sonoma and later)

### **Architecture Principles**
- **Native Performance**: Swift compilation for optimal CPU/memory usage
- **Low-Level System Access**: Direct hardware monitoring via IOKit
- **Efficient Data Collection**: Smart sampling to minimize CPU overhead (<1% target)
- **Privacy-First Design**: All data processing happens locally
- **Modular Architecture**: Plugin system for extensibility
- **Modern UI**: SwiftUI with customizable themes and layouts
- **Hybrid Approach**: SwiftUI for main UI + AppKit for system integration

## 📅 Timeline Estimates

- **Phase 1**: 4-6 weeks (Foundation & Core Monitoring)
- **Phase 2**: 3-4 weeks (Display Modes)
- **Phase 3**: 6-8 weeks (Unique Features)
- **Phase 4**: 4-5 weeks (Advanced Features)
- **Phase 5**: 3-4 weeks (Polish & Launch)
- **Phase 6**: Ongoing (Future Enhancements)

**Total Estimated Development Time**: 20-27 weeks (5-7 months)

## 🎯 Success Metrics

- **Performance**: <1% CPU usage during normal operation
- **Accuracy**: Real-time data updates with <100ms latency
- **Usability**: Intuitive interface requiring minimal learning curve
- **Reliability**: 99.9% uptime with comprehensive error handling
- **Privacy**: Zero data transmission to external servers

---

*Last Updated: 2025-11-02*
- Added comprehensive S.M.A.R.T. disk health monitoring roadmap (120+ features)
- Marked basic S.M.A.R.T. implementation as complete (Phase 1A/1B foundation)
- Organized S.M.A.R.T. features into 9 implementation phases with priorities

*Version: 1.1*
