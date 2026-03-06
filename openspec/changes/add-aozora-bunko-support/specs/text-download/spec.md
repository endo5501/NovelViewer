## MODIFIED Requirements

### Requirement: UI text for sister sites
The download dialog SHALL indicate that Narou sister sites (`novel18.syosetu.com`) and Aozora Bunko (`www.aozora.gr.jp`) are supported.

#### Scenario: UI hint text includes novel18
- **WHEN** the download dialog is displayed
- **THEN** the URL input hint text SHALL indicate that both `ncode.syosetu.com` and `novel18.syosetu.com` are supported

#### Scenario: UI hint text includes Aozora Bunko
- **WHEN** the download dialog is displayed
- **THEN** the URL input hint text SHALL indicate that `www.aozora.gr.jp` is supported

#### Scenario: Error message includes sister sites
- **WHEN** the user enters an unsupported URL
- **THEN** the error message SHALL mention that Narou sister sites (novel18.syosetu.com) and Aozora Bunko (www.aozora.gr.jp) are also supported
