🐰 Bunny Hop
Hop over the limits of connectivity.
An offline-capable, phone-based walkie-talkie and team communication system.

![DEFINE 4.0](https://img.shields.io/badge/DEFINE-4.0-7C3AED?style=for-the-badge)
![Flutter](https://img.shields.io/badge/Flutter-Mobile_App-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Go](https://img.shields.io/badge/Go-Backend-00ADD8?style=for-the-badge&logo=go&logoColor=white)
![SQLite](https://img.shields.io/badge/Database-SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)
![WebSockets](https://img.shields.io/badge/Realtime-WebSockets-4B5563?style=for-the-badge)
![Docker](https://img.shields.io/badge/Deployment-Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Bunny Hop project cover](https://github.com/user-attachments/assets/e51ded79-3cfb-4c38-b48b-0d1efdd0030c)
Overview · Features · Architecture · Setup · Team
---
<h1> Project Information </h1>
Field	Details
Project	Bunny Hop
Hackathon	DEFINE 4.0 — The World's Realest Hackathon
Team Name:	Japanese Footstep
Track:	Software Track
Demo Video:	`[Add demonstration video URL]`

<h1> Overview </h1>
Bunny Hop is an offline-capable communication application that transforms smartphones into affordable, software-defined walkie-talkies. Built with Flutter for the mobile application and powered by a lightweight Go backend, it enables teams to communicate over a local network without depending on internet connectivity or cloud infrastructure.
When the primary server becomes unavailable, Bunny Hop is designed to fall back to nearby-device communication, helping teams maintain essential coordination during network outages.
> **Our principle:** When connectivity fails, coordination should not have to stop.

<h1> Problem Statement </h1>
Reliable communication is essential in environments where coordination, situational awareness, and rapid information exchange directly affect operational efficiency and safety. However, conventional communication systems can be expensive to deploy at scale or unreliable when internet connectivity and centralized infrastructure are unavailable.
<h2> What problem are we solving? </h2>
Internet-dependent messaging and calling applications become unusable or severely limited when connectivity fails.
Traditional walkie-talkies primarily support voice communication and generally lack integrated messaging, photo sharing, digital acknowledgements, and centralized team management.
Commercial radio systems can require dedicated hardware and infrastructure, increasing deployment and maintenance costs.
Centralized communication systems may become a single point of failure when their servers or network infrastructure are unavailable.
Teams operating across large facilities or temporary sites need a practical way to coordinate without relying on external connectivity.
<h2> Who is affected? </h2>
Disaster-response and emergency-management teams.
Campus security personnel and event organizers.
Warehouse, construction, and industrial field crews.
Search-and-rescue teams operating in areas with unreliable connectivity.
Teams working in remote locations or temporary operational environments.
<h3> Why does it matter? </h3>
During emergencies and network outages, teams must continue exchanging instructions, status updates, and alerts. Communication should remain accessible, affordable, and usable even when internet services are unavailable. A smartphone-based solution can reduce dependence on dedicated radio hardware while providing richer communication and coordination capabilities.
<h2> Limitations of existing solutions </h2>
Traditional walkie-talkies	Primarily voice-oriented, with limited digital messaging and centralized visibility.
Internet-based messaging applications	Depend on network connectivity and often cloud infrastructure.
Conventional VoIP applications	Generally require reachable signaling and media infrastructure and are not inherently designed for server-outage mesh communication.
Centralized local communication systems	Can lose functionality when their central server becomes unavailable unless a fallback mechanism is provided.
Bunny Hop addresses this gap by combining local-network communication, push-to-talk controls, smartphone-based messaging, and nearby-device fallback mechanisms in a single application.

<h1> The Solution </h1>
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
<h1> Key Features </h1> 
Push-to-talk communication — Half-duplex voice coordination with speaking-floor control, priority pre-emption, and a configurable timeout.
Invite-only access — QR-based invitations and JWT authentication support controlled access to teams and channels.
Offline-first messaging — Messages can be queued locally and synchronized when the connection becomes available again.
Text and photo sharing — Share messages and images through the local communication server.
Live voice calls — LiveKit-powered calling over the same LAN.
Administrative dashboard — Monitor online users, active channels, current speakers, and broadcast acknowledgements.
Emergency broadcasts — Send alerts to relevant channels and track acknowledgements.
Nearby-device fallback — Android Nearby Connections supports direct text and SOS communication when the central server is unavailable.
Cross-platform direction — The architecture explores Android-assisted local connectivity for iOS devices during outages.
> **Implementation note:** Fallback features depend on the platform and the functionality implemented and tested in the current build. Server-backed voice, messaging, and administration should not be assumed to remain available during a server outage.

<h1>Technology Stack</h1>
Category	Technologies
Mobile frontend	Flutter, Dart
Backend	Go, Gin, Gorilla WebSocket
Database	SQLite
Voice communication	LiveKit
Nearby-device communication	Google Nearby Connections
Authentication	JSON Web Tokens (JWT)
Real-time communication	WebSockets, LiveKit
Offline communication	Android Nearby Connections, local-network communication
Admin dashboard	HTML, CSS, JavaScript
Containerization / deployment	Docker
Development tools	Git, GitHub

<h1> System Architecture </h1>
![Bunny Hop system architecture](https://github.com/user-attachments/assets/6753485d-c329-493b-85a3-19b806e1d283)
<sub>System architecture overview</sub>
Architecture overview
Bunny Hop follows a local-first communication architecture.
Mobile clients: Flutter applications provide the user interface for communication, channels, messaging, and push-to-talk.
Go backend: Handles authentication, user and channel coordination, real-time messaging, speaking permissions, and administrative operations.
WebSocket communication: Persistent connections support real-time updates between mobile clients and the backend.
LiveKit: Provides voice communication over the local network.
SQLite: Stores server-side application data.
Admin dashboard: A lightweight web interface exposes operational information and administrative communication controls.
Nearby-device fallback: Android devices can exchange essential messages directly through Google Nearby Connections when the primary server is unavailable.
The local-server architecture avoids mandatory cloud dependencies. Nearby-device fallback provides an additional communication path, although available features and platform support depend on the device and implementation.

<h1> Demo </h1>
Demo video: `[Add the actual demonstration video URL]`
Live project / deployment: `[Add URL if available]`
To try the project locally, follow the setup instructions.
<h1> Screenshots </h1>
![Bunny Hop mobile screenshot 1](https://github.com/user-attachments/assets/3f963242-7140-4465-bbba-87ef251ea849)
![Bunny Hop mobile screenshot 2](https://github.com/user-attachments/assets/25134ad8-3d8d-4366-b678-1d9087373c29)
![Bunny Hop mobile screenshot 3](https://github.com/user-attachments/assets/96e573a2-2365-4dd0-bd1c-5cc5007aa863)
![Bunny Hop mobile screenshot 4](https://github.com/user-attachments/assets/089d9c89-1f14-4445-b98f-ff220423baa4)
![Bunny Hop screenshot 5](https://github.com/user-attachments/assets/78cf43ab-a195-4b34-9023-cd0d78ed47fd)
![Bunny Hop screenshot 6](https://github.com/user-attachments/assets/865a37ef-1f38-4451-840f-a32156233137)

<h1> Setup Instructions </h1>
Prerequisites
Install and configure the following before running the project:
Go installed and available in `PATH`.
Flutter SDK and Dart SDK.
Android Studio or another Flutter-compatible development environment.
Android SDK and platform tools.
Windows PowerShell for the commands below.
Git.
Docker if the project's LiveKit setup uses Docker.
Android devices or emulators for testing.
A compatible local Wi-Fi network for LAN communication tests.
Internet access may be required initially to download dependencies. The intended local communication workflow does not require internet access once the necessary components are available.
1. Clone the repository
Replace the placeholders with the actual repository URL and directory name.
```powershell
git clone <repository-url>
cd <repository-directory>
```
2. Terminal 1 — Build the backend
From the Go backend project root, run:
```powershell
go build -o ptt-server.exe .
```
To intentionally start with a fresh local database, remove the existing database files:
```powershell
del server\ptt.db*
del ptt.db*
```
> ⚠️ **Warning:** These commands permanently delete matching database files. Skip them if you need to preserve existing data. Run the commands from the project directory where these paths are valid.
3. Terminal 2 — Start the backend server
Open a second PowerShell terminal in the same project directory and run:
```powershell
.\ptt-server.exe
```
Keep this terminal open while using Bunny Hop.
4. Terminal 3 — Configure the firewall
Open a third PowerShell terminal in the project directory and run:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\open-firewall.ps1
```
If prompted for elevated privileges, open PowerShell as an administrator and run the firewall script as required. Review the script before executing it and allow only the network access needed for your environment.
5. Set up and run the Flutter application
In a terminal opened in the Flutter application directory, run:
```powershell
flutter pub get
flutter devices
flutter run
```
Ensure that the app is configured with the backend's reachable LAN IP address and correct port.
> **Important:** On a physical phone, `localhost` refers to the phone itself, not the computer running the Go server. Use the computer's reachable local-network IP address when configuring the app.
6. Configure LiveKit
If LiveKit is part of the local deployment, start it using the configuration provided by the repository. For a project that includes a Docker Compose configuration, the command may be:
```powershell
docker compose up -d
```
Configure the LiveKit endpoint and credentials according to the project's configuration. The endpoint must be reachable over the local network for LAN-based voice communication. Use appropriate credentials and secure configuration outside development environments.
7. Test nearby-device fallback
After confirming that server-backed communication works:
Test direct nearby communication between supported Android devices.
Make the primary server unavailable.
Verify the implemented text and SOS fallback features.
Restore the server and verify synchronization of queued messages where supported.
Available fallback features depend on the platform and implementation. Do not assume that all server-backed voice, messaging, and administrative features remain available during a server outage.
🧪 # Validation Checklist
Use this checklist when testing a local deployment:
[ ] Backend builds and starts successfully.
[ ] Mobile app can reach the backend over the local network.
[ ] Authentication and invite-only access work as expected.
[ ] Push-to-talk floor control prevents overlapping speakers as designed.
[ ] Text and photo sharing work in local-server mode.
[ ] Offline messages queue and synchronize where supported.
[ ] LiveKit voice communication works over the LAN.
[ ] Admin dashboard displays the expected users, channels, and speaker state.
[ ] Emergency broadcasts and acknowledgements work as expected.
[ ] Nearby-device text and SOS fallback work on supported Android devices.
[ ] Firewall rules expose only the necessary services.
⚠️ # Project Status and Limitations
Bunny Hop is designed to maintain essential team communication when internet connectivity or centralized infrastructure becomes unavailable.
Local-server mode: Provides the server-backed communication features, including messaging, administration, and LAN-based voice functionality.
Nearby fallback mode: The described Android implementation supports text and SOS messages.
Cross-platform connectivity: Android-assisted connectivity for iOS should be documented as implemented only where the corresponding functionality has been tested.
Nearby-device communication is subject to radio range, device compatibility, operating-system restrictions, and wireless conditions. It should not be assumed to provide unrestricted long-range communication or complete voice-call functionality when the primary server is unavailable.
🔭 # Future Scope
Extend nearby-device communication through multi-hop relaying where supported.
Improve cross-platform fallback support between Android and iOS devices.
Investigate voice communication over the fallback network.
Add stronger message-delivery guarantees and synchronization conflict handling.
Improve network discovery, reconnection, and failure recovery.
Expand monitoring and administrative controls for larger teams.
Evaluate communication reliability under different network and device conditions.
👥 # Team Information
Team name: Japanese Footstep  
Track: Software
Name	Role	GitHub	LinkedIn
Advaith Manoj	Team Member	@advaithmanoj-05	Advaith Manoj
Adithyan S K	Team Member	@Just-Ads05	Adithyan S K
Adithya P	Team Member	@capedcrusader-39	`[Add LinkedIn URL]`
E V Jishnu	Team Leader	@Jishnu-Vasudev	E V Jishnu
🤝 # Contributing
Contributions, issue reports, and suggestions are welcome.
Fork the repository.
Create a feature branch: `git switch -c feature/your-feature`.
Make and test your changes.
Commit your work with a clear message.
Push the branch and open a pull request.
Please replace this section with any official contribution guidelines required by the project.
📄 # License
The project license has not yet been specified.
Add the appropriate open-source license before distributing the project publicly. Until a license is added, do not assume that the code is available for unrestricted reuse.
🙌 # Acknowledgements
Built by Japanese Footstep for DEFINE 4.0 — The World's Realest Hackathon.
When connectivity fails, coordination should not have to stop. 🐰
