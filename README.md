DEFINE 4.0
The official project submission repository for DEFINE 4.0 — The World's Realest Hackathon.
Bunny Hop
A phone-based, offline-capable walkie-talkie system for reliable team communication when internet connectivity is unavailable.
<!-- Add your project cover image below -->
<img width="2172" height="724" alt="image" src="https://github.com/user-attachments/assets/e51ded79-3cfb-4c38-b48b-0d1efdd0030c" />


Team Information
- Team Name: Japanese Footstep
- Track: To be updated
Team Members
Name	Role	GitHub	LinkedIn
Advaith Manoj	Team Member	@advaithmanoj-05	[Advaith Manoj](https://www.linkedin.com/in/advaith-manoj-023b12291?utm_source=share_via&utm_content=profile&utm_medium=member_ios)
Adithyan S K	Team Member	@Just-Ads05	[Adithyan S K](https://www.linkedin.com/in/adithyan-sk?utm_source=share_via&utm_content=profile&utm_medium=member_android)
Adithya P	Team Member	@capedcrusader-39	Adithya P
E V Jishnu	Team Leader	@Jishnu-Vasudev	[E V Jishnu](https://www.linkedin.com/in/jishnu-ev-367a60330?utm_source=share_via&utm_content=profile&utm_medium=member_android)


Project Details
Overview
Bunny Hop is an offline-capable communication application that transforms smartphones into affordable, software-defined walkie-talkies. Built entirely with Flutter for its mobile application and powered by a lightweight Go backend, it enables teams to communicate over a local network without depending on internet connectivity or cloud infrastructure. When the primary server becomes unavailable, Bunny Hop is designed to fall back to nearby-device communication, helping teams maintain essential coordination during network outages.
Problem Statement
Reliable communication is essential in environments where coordination, situational awareness, and rapid information exchange can directly affect operational efficiency and safety. However, conventional communication systems often become expensive to deploy at scale or unreliable when internet connectivity and centralized infrastructure are unavailable.
What is the problem?
- Internet-dependent messaging and calling applications become unusable or severely limited when connectivity fails.
- Traditional walkie-talkies primarily support voice communication and generally lack integrated messaging, photo sharing, digital acknowledgements, and centralized team management.
- Commercial radio systems can require dedicated hardware and infrastructure, increasing deployment and maintenance costs.
- Centralized communication systems may become a single point of failure when their servers or network infrastructure are unavailable.
- Teams operating across large facilities or temporary sites need a practical way to coordinate without relying on external connectivity.
Who is affected?
- Disaster-response and emergency-management teams.
- Campus security personnel and event organizers.
- Warehouse, construction, and industrial field crews.
- Search-and-rescue teams operating in areas with unreliable connectivity.
- Teams working in remote locations or temporary operational environments.
Why is solving it important?
During emergencies and network outages, teams must continue exchanging instructions, status updates, and alerts. Communication should remain accessible, affordable, and usable even when internet services are unavailable. A smartphone-based solution can reduce dependence on dedicated radio hardware while providing richer communication and coordination capabilities.
Limitations of existing solutions
Existing solution	Limitations
Traditional walkie-talkies	Primarily voice-oriented, with limited digital messaging and centralized visibility.
Internet-based messaging applications	Depend on network connectivity and often cloud infrastructure.
Conventional VoIP applications	Generally require a reachable signaling and media infrastructure and are not inherently designed for server-outage mesh communication.
Centralized local communication systems	Can lose functionality when their central server becomes unavailable unless a fallback mechanism is provided.


Bunny Hop addresses this gap by combining local-network communication, push-to-talk controls, smartphone-based messaging, and nearby-device fallback mechanisms in a single application.
Solution
Bunny Hop provides a communication platform that uses the phones teams already carry instead of requiring every participant to purchase a dedicated walkie-talkie.
How it works
1. Normal operation — local server
A lightweight Go server acts as the central communication point for participating devices on a local network. Phones connect to the server over the LAN, allowing the application to operate without requiring internet access, cloud hosting, or external messaging services.
2. Controlled voice communication
Bunny Hop provides push-to-talk functionality with server-side floor control. The system supports half-duplex communication, priority-based pre-emption, and a speaking timeout to reduce overlapping transmissions. LiveKit provides voice-calling capabilities over the local network.
3. Messaging and information sharing
Users can exchange text messages and photos. Messages created while the server is unreachable can be queued locally and synchronized when connectivity returns, with offline messages identified during synchronization.
4. Server-outage fallback
When the primary server becomes unavailable, Bunny Hop is designed to use nearby-device communication to maintain essential coordination. Google Nearby Connections is used for direct Android device communication, supporting text and SOS messages in the fallback implementation described in the current project design.
The broader cross-platform design also explores using an Android device as a local communication server for nearby iOS devices. This approach is intended to address differences in wireless connectivity capabilities between Android and iOS.
5. Team coordination and administration
An administrative dashboard provides visibility into connected users, active channels, current speakers, and emergency broadcasts. Acknowledgements help administrators determine whether important announcements have been received.
Core technologies
- Flutter for the cross-platform mobile application.
- Go for the lightweight backend server.
- LiveKit for voice communication.
- Google Nearby Connections for Android nearby-device communication.
- SQLite for local server-side data persistence.
- WebSockets for real-time communication.
- JWT authentication for authenticated access.
Bunny Hop aims to provide a practical balance between the simplicity of walkie-talkies and the richer communication features of smartphone applications.
Demo
Demo Video
Watch the Bunny Hop Project Demo
Replace the placeholder with the actual demonstration video URL.

Screenshots
<!-- Add project screenshots to the assets directory before submission. -->
<img width="738" height="1600" alt="image" src="https://github.com/user-attachments/assets/3f963242-7140-4465-bbba-87ef251ea849" />
<img width="738" height="1600" alt="image" src="https://github.com/user-attachments/assets/25134ad8-3d8d-4366-b678-1d9087373c29" />
<img width="738" height="1600" alt="image" src="https://github.com/user-attachments/assets/96e573a2-2365-4dd0-bd1c-5cc5007aa863" />
<img width="738" height="1600" alt="image" src="https://github.com/user-attachments/assets/089d9c89-1f14-4445-b98f-ff220423baa4" />
<img width="1600" height="723" alt="image" src="https://github.com/user-attachments/assets/78cf43ab-a195-4b34-9023-cd0d78ed47fd" />
<img width="1600" height="1035" alt="image" src="https://github.com/user-attachments/assets/865a37ef-1f38-4451-840f-a32156233137" />




Live Project
Please clone the repository and follow instructions to get the project running.

Technical Implementation
Technologies Used
Category	Technologies
Frontend	Flutter, Dart
Backend	Go, Gin, Gorilla WebSocket
Database	SQLite
APIs / Services	LiveKit, Google Nearby Connections
Authentication	JSON Web Tokens (JWT)
Real-time Communication	WebSockets, LiveKit
Offline Communication	Android Nearby Connections, local-network communication
Admin Dashboard	HTML, CSS, JavaScript
Containerization / Deployment	Docker
Development Tools	Git, GitHub


System Architecture
<!-- Add the system architecture diagram to the assets directory. -->
<img width="1278" height="508" alt="image" src="https://github.com/user-attachments/assets/6753485d-c329-493b-85a3-19b806e1d283" />



Architecture Overview
Bunny Hop follows a local-first communication architecture.
1. Mobile clients: Flutter applications provide the user interface for communication, channels, messaging, and push-to-talk.
2. Go backend: The server handles authentication, user and channel coordination, real-time messaging, speaking permissions, and administrative operations.
3. WebSocket communication: Persistent connections support real-time updates between the mobile clients and backend.
4. LiveKit: Provides voice communication over the local network.
5. SQLite: Stores server-side application data.
6. Admin dashboard: A lightweight web interface exposes operational information and administrative communication controls.
7. Nearby-device fallback: Android devices can exchange essential messages directly through Google Nearby Connections when the primary server is unavailable.
The local-server architecture avoids mandatory cloud dependencies. Nearby-device fallback provides an additional communication path, although its available features and platform support depend on the device and implementation.
Key Features
- Push-to-talk communication: Half-duplex voice coordination with speaking-floor control, priority pre-emption, and a configurable timeout.
- Invite-only access: QR-based invitations and JWT authentication allow controlled access to teams and channels.
- Offline-first messaging: Messages can be queued locally and synchronized when the connection becomes available again.
- Text and photo sharing: Share messages and images through the local communication server.
- Live voice calls: LiveKit-powered calling over the same LAN.
- Administrative dashboard: Monitor online users, active channels, current speakers, and broadcast acknowledgements.
- Emergency broadcasts: Send alerts to relevant channels and track acknowledgements.
- Nearby-device fallback: Android Nearby Connections supports direct text and SOS communication when the central server is unavailable.
- Cross-platform direction: The architecture explores Android-assisted local connectivity for iOS devices during outages.
Setup Instructions
Prerequisites
Make sure the following are installed before running the project:
- Go installed and configured in PATH.
- Flutter SDK and Dart SDK.
- Android Studio or another Flutter-compatible development environment.
- Android SDK and platform tools.
- Windows PowerShell.
- Git.
- Docker, if the project's LiveKit setup uses Docker.
- Android devices or emulators for testing.
- A compatible local Wi-Fi network for LAN communication tests.
Internet access may be required initially to download dependencies. The intended local communication workflow does not require internet access once the necessary components are available.
Installation
1. Clone the Repository
git clone <repository-url>
cd <repository-directory>
Replace the placeholders with your repository URL and directory name.
2. Terminal 1 — Build the Backend
From the backend's Go project root, run:
go build -o ptt-server.exe .
If you intentionally want to start with a fresh local database, remove the existing database files:
del server\ptt.db*
del ptt.db*
Warning: These commands permanently delete matching database files. Skip them if you need to preserve existing data. Run the commands from the project directory where the paths are valid.
3. Terminal 2 — Start the Backend Server
Open a second PowerShell terminal in the same project directory and run:
.\ptt-server.exe
Keep this terminal open while using Bunny Hop.
4. Terminal 3 — Configure the Firewall
Open a third PowerShell terminal in the project directory and run:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\open-firewall.ps1
If prompted for elevated privileges, open PowerShell as an administrator and run the firewall script as required. Review the script before executing it and allow only the network access needed for your environment.
5. Set Up and Run the Flutter Application
In a terminal opened in the Flutter application directory, run:
flutter pub get
flutter devices
flutter run
Ensure that the app is configured with the backend's reachable LAN IP address and correct port.
Important: On a physical phone, localhost refers to the phone itself, not the computer running the Go server.
6. Configure LiveKit
If LiveKit is part of the local deployment, start it using the configuration provided by the repository. For a project that includes a Docker Compose configuration, the command may be:
docker compose up -d
Configure the LiveKit endpoint and credentials according to the project's configuration. The endpoint must be reachable over the local network for LAN-based voice communication. Use appropriate credentials and secure configuration outside development environments.
7. Test Nearby-Device Fallback
After confirming that server-backed communication works:
1. Test direct nearby communication between supported Android devices.
2. Make the primary server unavailable.
3. Verify the implemented text and SOS fallback features.
4. Restore the server and verify synchronization of queued messages where supported.
The available fallback features depend on the platform and implementation. Do not assume that all server-backed voice, messaging, and administrative features remain available during a server outage.
Project Status and Limitations
Bunny Hop is designed to maintain essential team communication when internet connectivity or centralized infrastructure becomes unavailable.
- Local-server mode: Provides the server-backed communication features, including messaging, administration, and LAN-based voice functionality.
- Nearby fallback mode: The described Android implementation supports text and SOS messages.
- Cross-platform connectivity: Android-assisted connectivity for iOS should be documented as implemented only where the corresponding functionality has been tested.
Nearby-device communication is subject to radio range, device compatibility, operating-system restrictions, and wireless conditions. It should not be assumed to provide unrestricted long-range communication or complete voice-call functionality when the primary server is unavailable.
Future Scope
- Extend nearby-device communication through multi-hop relaying where supported.
- Improve cross-platform fallback support between Android and iOS devices.
- Investigate voice communication over the fallback network.
- Add stronger message delivery guarantees and synchronization conflict handling.
- Improve network discovery, reconnection, and failure recovery.
- Expand monitoring and administrative controls for larger teams.
- Evaluate communication reliability under different network and device conditions.
License
Add the appropriate open-source license before distributing the project publicly.
Acknowledgements
Built by Japanese Footstep for DEFINE 4.0 — The World's Realest Hackathon.
Bunny Hop is built around one principle: when connectivity fails, coordination should not have to stop.
