import { db } from './db.js';
import { broadcastToChannel } from './ws.js';

export interface FloorHolder {
  userId: string;
  name: string;
  priority: number;
  expiresAt: number;
  timer: NodeJS.Timeout;
}

const floors = new Map<string, FloorHolder>();

export function getFloorHolder(channelId: string): FloorHolder | null {
  const holder = floors.get(channelId);
  if (!holder) return null;
  if (Date.now() > holder.expiresAt) {
    releaseFloor(channelId, holder.userId);
    return null;
  }
  return holder;
}

export function requestFloor(channelId: string, userId: string, priority = 1, timeoutMs = 30000): { granted: boolean; holder: string } {
  const now = Date.now();
  const current = floors.get(channelId);

  // If expired, clear it
  if (current && now > current.expiresAt) {
    clearTimeout(current.timer);
    floors.delete(channelId);
  }

  const active = floors.get(channelId);

  // If currently held by same user, refresh
  if (active && active.userId === userId) {
    clearTimeout(active.timer);
    active.expiresAt = now + timeoutMs;
    active.priority = Math.max(active.priority, priority);
    active.timer = setTimeout(() => {
      autoReleaseFloor(channelId, userId);
    }, timeoutMs);
    return { granted: true, holder: userId };
  }

  // If held by higher or equal priority, deny
  if (active && active.priority >= priority) {
    return { granted: false, holder: active.userId };
  }

  // If held by lower priority, pre-empt
  if (active && active.priority < priority) {
    clearTimeout(active.timer);
    // Notify old holder released
    broadcastToChannel(channelId, {
      t: 'floor',
      channel_id: channelId,
      state: 'released',
      user_id: active.userId,
      name: active.name,
      priority: active.priority,
    });
  }

  const user = db.prepare('SELECT name FROM users WHERE id = ?').get(userId) as { name: string } | undefined;
  const userName = user?.name || 'Unknown';

  const timer = setTimeout(() => {
    autoReleaseFloor(channelId, userId);
  }, timeoutMs);

  floors.set(channelId, {
    userId,
    name: userName,
    priority,
    expiresAt: now + timeoutMs,
    timer,
  });

  // Broadcast floor granted
  broadcastToChannel(channelId, {
    t: 'floor',
    channel_id: channelId,
    state: 'granted',
    user_id: userId,
    name: userName,
    priority,
  });

  return { granted: true, holder: userId };
}

export function releaseFloor(channelId: string, userId: string): boolean {
  const current = floors.get(channelId);
  if (!current) return true;

  if (current.userId === userId) {
    clearTimeout(current.timer);
    floors.delete(channelId);

    broadcastToChannel(channelId, {
      t: 'floor',
      channel_id: channelId,
      state: 'released',
      user_id: userId,
      name: current.name,
      priority: current.priority,
    });
    return true;
  }

  return false;
}

function autoReleaseFloor(channelId: string, userId: string) {
  const current = floors.get(channelId);
  if (current && current.userId === userId) {
    floors.delete(channelId);
    broadcastToChannel(channelId, {
      t: 'floor',
      channel_id: channelId,
      state: 'released',
      user_id: userId,
      name: current.name,
      priority: current.priority,
    });
  }
}

export function releaseUserFloors(userId: string) {
  for (const [channelId, holder] of floors.entries()) {
    if (holder.userId === userId) {
      clearTimeout(holder.timer);
      floors.delete(channelId);
      broadcastToChannel(channelId, {
        t: 'floor',
        channel_id: channelId,
        state: 'released',
        user_id: userId,
        name: holder.name,
        priority: holder.priority,
      });
    }
  }
}
