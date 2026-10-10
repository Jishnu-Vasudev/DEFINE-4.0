import { useState, type ReactNode } from "react"

type IconName = "arrow" | "bars" | "broadcast" | "check" | "chevron" | "help" | "info" | "link" | "mic" | "moon" | "more" | "paperclip" | "plane" | "qr" | "settings" | "shield" | "sun" | "team" | "user"

const iconPaths: Record<IconName, ReactNode> = {
  arrow: <path d="m15 18-6-6 6-6" />,
  bars: <path d="M4 7h16M4 12h16M4 17h12" />,
  broadcast: (
    <>
      <circle cx="12" cy="11" r="2" />
      <path d="M7.8 6.8a6 6 0 0 0 0 8.4M16.2 6.8a6 6 0 0 1 0 8.4M4.6 3.6a10.5 10.5 0 0 0 0 14.8M19.4 3.6a10.5 10.5 0 0 1 0 14.8M12 13v8" />
    </>
  ),
  check: <path d="m5 12 4 4L19 6" />,
  chevron: <path d="m9 18 6-6-6-6" />,
  help: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M9.8 9a2.4 2.4 0 1 1 3.4 2.2c-.8.4-1.2.9-1.2 1.8M12 17h.01" />
    </>
  ),
  info: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 11v6M12 7h.01" />
    </>
  ),
  link: (
    <path d="M10 13a5 5 0 0 0 7.1.1l2-2a5 5 0 0 0-7.1-7.1l-1.1 1.1M14 11a5 5 0 0 0-7.1-.1l-2 2A5 5 0 0 0 12 20l1.1-1.1" />
  ),
  mic: (
    <>
      <rect x="9" y="3" width="6" height="12" rx="3" />
      <path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M9 21h6" />
    </>
  ),
  moon: <path d="M20 15.2A8.5 8.5 0 0 1 8.8 4a8.5 8.5 0 1 0 11.2 11.2Z" />,
  more: (
    <>
      <circle cx="12" cy="5" r="1" fill="currentColor" stroke="none" />
      <circle cx="12" cy="12" r="1" fill="currentColor" stroke="none" />
      <circle cx="12" cy="19" r="1" fill="currentColor" stroke="none" />
    </>
  ),
  paperclip: (
    <path d="m20.5 11.5-8.9 8.9a6 6 0 0 1-8.5-8.5l9.6-9.6a4 4 0 0 1 5.7 5.7l-9.6 9.6a2 2 0 0 1-2.8-2.8l8.9-8.9" />
  ),
  plane: <path d="m3 3 18 9-18 9 3.5-7.5L15 12l-8.5-1.5L3 3Z" />,
  qr: (
    <path d="M4 4h6v6H4V4Zm10 0h6v6h-6V4ZM4 14h6v6H4v-6Zm11 0h2v2h-2v-2Zm3 0h2v4h-2v-4Zm-4 4h4v2h-4v-2Z" />
  ),
  settings: (
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z" />
    </>
  ),
  shield: (
    <path d="M12 3 5 6v5c0 4.5 2.8 8.1 7 10 4.2-1.9 7-5.5 7-10V6l-7-3Zm-3 9 2 2 4-4" />
  ),
  sun: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </>
  ),
  team: (
    <>
      <circle cx="9" cy="9" r="3" />
      <circle cx="17" cy="10" r="2" />
      <path d="M3.5 19c.5-3.5 2.4-5 5.5-5s5 1.5 5.5 5M14 15c3.6-.7 5.8.7 6.5 4" />
    </>
  ),
  user: (
    <>
      <circle cx="12" cy="8" r="4" />
      <path d="M4.5 21a7.5 7.5 0 0 1 15 0" />
    </>
  ),
}

function Icon({ name, size = 20 }: { name: IconName size?: number }) {
  return (
    <svg
      aria-hidden="true"
      className="icon"
      fill="none"
      height={size}
      viewBox="0 0 24 24"
      width={size}
    >
      {iconPaths[name]}
    </svg>
  )
}

function Action({
  children,
  className = "",
  label,
  onClick,
  onPointerDown,
  onPointerUp,
}: {
  children: ReactNode
  className?: string
  label: string
  onClick?: () => void
  onPointerDown?: () => void
  onPointerUp?: () => void
}) {
  return (
    <button
      aria-label={label}
      className={className}
      onClick={onClick}
      onPointerDown={onPointerDown}
      onPointerLeave={onPointerUp}
      onPointerUp={onPointerUp}
      type="button"
    >
      {children}
    </button>
  )
}

function StatusBar() {
  return (
    <div className="status-bar">
      <span>9:41</span>
      <span className="status-icons">
        <i />
        <i />
        <i />
        <b>92</b>
      </span>
    </div>
  )
}

function Phone({ children, label }: { children: ReactNode label: string }) {
  return (
    <section className="phone-wrap" aria-label={label}>
      <div className="phone">
        <div className="phone-glow" />
        <StatusBar />
        {children}
        <div className="home-indicator" />
      </div>
    </section>
  )
}

function RoundAction({
  icon,
  label,
  onClick,
}: {
  icon: IconName
  label: string
  onClick?: () => void
}) {
  return (
    <Action className="round-action" label={label} onClick={onClick}>
      <Icon name={icon} />
    </Action>
  )
}

function Toggle({
  active,
  label,
  onClick,
}: {
  active: boolean
  label: string
  onClick: () => void
}) {
  return (
    <Action
      className={`toggle ${active ? "active" : ""}`}
      label={label}
      onClick={onClick}
    >
      <span />
    </Action>
  )
}

function ChatScreen() {
  const [talking, setTalking] = useState(false)
  return (
    <Phone label="Channel chat screen">
      <header className="app-header">
        <RoundAction icon="arrow" label="Go back" />
        <div className="header-title centered">
          <strong>Chan 1</strong>
          <span className="badge">
            <i /> Team Channel
          </span>
        </div>
        <RoundAction icon="more" label="More options" />
      </header>

      <main className="chat-empty">
        <div className="empty-orbit">
          <span />
        </div>
        <p>No messages yet. Say hi 👋</p>
        <small>Your team is connected and ready.</small>
      </main>

      <div className="composer glass">
        <Action className="composer-side" label="Attach file">
          <Icon name="paperclip" size={19} />
        </Action>
        <Action
          className={`talk-button ${talking ? "talking" : ""}`}
          label="Hold to talk"
          onPointerDown={() => setTalking(true)}
          onPointerUp={() => setTalking(false)}
        >
          <span className="mic-orbit">
            <Icon name="mic" size={19} />
          </span>
          <span>{talking ? "Listening…" : "Hold to talk"}</span>
        </Action>
        <Action className="composer-side send" label="Send message">
          <Icon name="plane" size={18} />
        </Action>
      </div>
    </Phone>
  )
}

function ChannelScreen({
  dark,
  onThemeToggle,
}: {
  dark: boolean
  onThemeToggle: () => void
}) {
  const [drawerOpen, setDrawerOpen] = useState(true)

  return (
    <Phone label="Channels screen with navigation drawer">
      <header className="app-header">
        <RoundAction
          icon="bars"
          label="Open menu"
          onClick={() => setDrawerOpen(true)}
        />
        <div className="header-title centered">
          <strong>Channels</strong>
          <span>1 active channel</span>
        </div>
        <RoundAction icon="more" label="More options" />
      </header>

      <main className="channel-content">
        <div className="identity-row">
          <div className="avatar">H</div>
          <div>
            <small>WELCOME BACK</small>
            <p>Signed in as H</p>
          </div>
        </div>
        <div className="section-label">
          <span>YOUR CHANNELS</span>
          <b>1</b>
        </div>
        <Action className="channel-card glass" label="Open Chan 1">
          <span className="channel-icon">
            <Icon name="team" size={23} />
          </span>
          <span className="channel-copy">
            <strong>Chan 1</strong>
            <small>
              <i /> Team channel
            </small>
          </span>
          <Icon name="chevron" size={18} />
        </Action>
        <Action className="join-channel" label="Join new channel">
          <span>+</span>
          Join New Channel
        </Action>
      </main>

      <div className={`drawer-layer ${drawerOpen ? "open" : ""}`}>
        <Action
          className="drawer-scrim"
          label="Close menu"
          onClick={() => setDrawerOpen(false)}
        >
          <span />
        </Action>
        <aside className="drawer glass">
          <div className="drawer-brand">
            <div className="brand-mark">
              <Icon name="broadcast" size={22} />
            </div>
            <div>
              <strong>Communicator</strong>
              <span>OS</span>
            </div>
          </div>
          <div className="drawer-profile">
            <div className="avatar">H</div>
            <div>
              <small>ACCOUNT</small>
              <p>Signed in as H</p>
            </div>
          </div>
          <nav className="drawer-nav">
            <div className="drawer-item">
              <span className="drawer-item-icon">
                <Icon name={dark ? "moon" : "sun"} size={18} />
              </span>
              <span>
                <strong>{dark ? "Dark mode" : "Light mode"}</strong>
                <small>Appearance</small>
              </span>
              <Toggle
                active={dark}
                label="Toggle color theme"
                onClick={onThemeToggle}
              />
            </div>
            <Action className="drawer-item" label="Open support and help">
              <span className="drawer-item-icon">
                <Icon name="help" size={18} />
              </span>
              <span>
                <strong>Support & Help</strong>
                <small>Guides and contact</small>
              </span>
              <Icon name="chevron" size={16} />
            </Action>
          </nav>
          <div className="version-row">
            <Icon name="info" size={17} />
            <span>Version Info</span>
            <strong>v1.2.0-stable</strong>
          </div>
        </aside>
      </div>
    </Phone>
  )
}

function JoinScreen() {
  const [name, setName] = useState("")
  return (
    <Phone label="Join your team screen">
      <main className="join-content">
        <div className="join-visual">
          <div className="sphere">
            <div className="sphere-shine" />
            <Icon name="broadcast" size={36} />
          </div>
          <span className="radar-ring ring-one" />
          <span className="radar-ring ring-two" />
        </div>
        <div className="join-heading">
          <span className="eyebrow">PRIVATE ACCESS</span>
          <h1>Join your team</h1>
          <p>Private network. Ask your admin for an invite QR.</p>
        </div>
        <label className="name-field glass">
          <Icon name="user" size={20} />
          <input
            aria-label="Your name"
            onChange={(event) => setName(event.target.value)}
            placeholder="Your name"
            value={name}
          />
          {name && (
            <span className="valid">
              <Icon name="check" size={14} />
            </span>
          )}
        </label>
        <Action className="primary-cta" label="Scan invite QR">
          <Icon name="qr" size={21} />
          <span>Scan invite QR</span>
          <Icon name="chevron" size={17} />
        </Action>
        <Action className="text-link" label="Enter code manually">
          Enter code manually <span>→</span>
        </Action>
        <div className="secure-note">
          <Icon name="shield" size={14} />
          End-to-end encrypted
        </div>
      </main>
    </Phone>
  )
}

const helpTopics = [
  {
    icon: "broadcast" as IconName,
    title: "Connection issues",
    detail: "Audio, network and P2P help",
  },
  {
    icon: "qr" as IconName,
    title: "Joining a team",
    detail: "Invites, QR codes and access",
  },
  {
    icon: "shield" as IconName,
    title: "Privacy & security",
    detail: "Your data and encryption",
  },
]

function SupportScreen() {
  const [query, setQuery] = useState("")
  const visibleTopics = helpTopics.filter((topic) =>
    `${topic.title} ${topic.detail}`
      .toLowerCase()
      .includes(query.toLowerCase()),
  )

  return (
    <Phone label="Support and help screen">
      <header className="app-header support-header">
        <RoundAction icon="arrow" label="Go back" />
        <div className="header-title centered">
          <strong>Support & Help</strong>
          <span>We’re here for you</span>
        </div>
        <div className="header-spacer" />
      </header>
      <main className="support-content">
        <section className="support-hero">
          <div className="support-orb">
            <Icon name="help" size={28} />
          </div>
          <span className="eyebrow">HELP CENTER</span>
          <h1>How can we help?</h1>
          <p>Search our guides or connect with a support specialist.</p>
        </section>

        <label className="support-search glass">
          <Icon name="help" size={18} />
          <input
            aria-label="Search help"
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search help topics"
            value={query}
          />
        </label>

        <div className="support-section-title">
          <span>POPULAR TOPICS</span>
          <small>{visibleTopics.length} guides</small>
        </div>
        <section className="topic-list glass">
          {visibleTopics.length > 0 ? (
            visibleTopics.map((topic) => (
              <Action
                className="topic-row"
                key={topic.title}
                label={`Open ${topic.title}`}
              >
                <span className="topic-icon">
                  <Icon name={topic.icon} size={17} />
                </span>
                <span className="topic-copy">
                  <strong>{topic.title}</strong>
                  <small>{topic.detail}</small>
                </span>
                <Icon name="chevron" size={15} />
              </Action>
            ))
          ) : (
            <div className="no-topics">
              No guides found. Try another search.
            </div>
          )}
        </section>

        <div className="contact-card">
          <span className="contact-icon">
            <Icon name="help" size={20} />
          </span>
          <span>
            <strong>Still need help?</strong>
            <small>Average reply time: 5 minutes</small>
          </span>
          <Action className="contact-button" label="Contact support">
            Chat now
          </Action>
        </div>
        <Action className="status-link" label="View system status">
          <span />
          All systems operational
          <Icon name="chevron" size={13} />
        </Action>
      </main>
    </Phone>
  )
}

export default function App() {
  const [dark, setDark] = useState(false)
  const toggleTheme = () => setDark((current) => !current)

  return (
    <div className={`app-shell ${dark ? "theme-dark" : "theme-light"}`}>
      <div className="ambient ambient-one" />
      <div className="ambient ambient-two" />
      <header className="showcase-header">
        <div>
          <span className="showcase-kicker">COMMUNICATOR OS · CONCEPT 01</span>
          <h2>Stay close. Speak instantly.</h2>
        </div>
        <div className="global-theme glass">
          <Icon name={dark ? "moon" : "sun"} size={17} />
          <span>{dark ? "Dark" : "Light"} mode</span>
          <Toggle active={dark} label="Toggle theme" onClick={toggleTheme} />
        </div>
      </header>
      <div className="screens">
        <ChatScreen />
        <ChannelScreen dark={dark} onThemeToggle={toggleTheme} />
        <JoinScreen />
        <SupportScreen />
      </div>
    </div>
  )
}
