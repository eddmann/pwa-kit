/**
 * Tests for notifications module
 */

import { describe, it, expect, beforeEach, afterEach, vi, type Mock } from 'vitest';
import { notifications } from '../src/ios/notifications';
import { bridge } from '../src/bridge';

// Mock the bridge module
vi.mock('../src/bridge', () => ({
  bridge: {
    call: vi.fn(),
  },
}));

describe('notifications module', () => {
  const mockCall = bridge.call as Mock;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('schedule', () => {
    it('schedules a time interval notification', async () => {
      mockCall.mockResolvedValueOnce({ success: true, id: 'test-id' });

      const id = await notifications.schedule({
        id: 'test-id',
        title: 'Test Notification',
        body: 'Test body',
        trigger: { type: 'timeInterval', seconds: 60 },
      });

      expect(id).toBe('test-id');
      expect(mockCall).toHaveBeenCalledWith('notifications', 'schedule', {
        id: 'test-id',
        title: 'Test Notification',
        body: 'Test body',
        subtitle: undefined,
        badge: undefined,
        sound: undefined,
        data: undefined,
        trigger: { type: 'timeInterval', seconds: 60 },
      });
    });

    it('schedules a repeating time interval notification', async () => {
      mockCall.mockResolvedValueOnce({ success: true, id: 'hourly' });

      const id = await notifications.schedule({
        id: 'hourly',
        title: 'Hourly Reminder',
        trigger: { type: 'timeInterval', seconds: 3600, repeats: true },
      });

      expect(id).toBe('hourly');
      expect(mockCall).toHaveBeenCalledWith('notifications', 'schedule', {
        id: 'hourly',
        title: 'Hourly Reminder',
        body: undefined,
        subtitle: undefined,
        badge: undefined,
        sound: undefined,
        data: undefined,
        trigger: { type: 'timeInterval', seconds: 3600, repeats: true },
      });
    });

    it('schedules a date notification with Date object', async () => {
      mockCall.mockResolvedValueOnce({ success: true, id: 'meeting' });

      const meetingDate = new Date('2024-12-25T10:00:00Z');
      const id = await notifications.schedule({
        id: 'meeting',
        title: 'Meeting',
        trigger: { type: 'date', date: meetingDate },
      });

      expect(id).toBe('meeting');
      expect(mockCall).toHaveBeenCalledWith('notifications', 'schedule', {
        id: 'meeting',
        title: 'Meeting',
        body: undefined,
        subtitle: undefined,
        badge: undefined,
        sound: undefined,
        data: undefined,
        trigger: { type: 'date', date: meetingDate.toISOString() },
      });
    });

    it('schedules a date notification with ISO string', async () => {
      mockCall.mockResolvedValueOnce({ success: true, id: 'event' });

      const id = await notifications.schedule({
        id: 'event',
        title: 'Event',
        trigger: { type: 'date', date: '2024-12-25T10:00:00Z' },
      });

      expect(id).toBe('event');
      expect(mockCall).toHaveBeenCalledWith('notifications', 'schedule', {
        id: 'event',
        title: 'Event',
        body: undefined,
        subtitle: undefined,
        badge: undefined,
        sound: undefined,
        data: undefined,
        trigger: { type: 'date', date: '2024-12-25T10:00:00Z' },
      });
    });

    it('schedules a calendar notification', async () => {
      mockCall.mockResolvedValueOnce({ success: true, id: 'daily' });

      const id = await notifications.schedule({
        id: 'daily',
        title: 'Good morning!',
        trigger: { type: 'calendar', hour: 9, minute: 0, repeats: true },
      });

      expect(id).toBe('daily');
      expect(mockCall).toHaveBeenCalledWith('notifications', 'schedule', {
        id: 'daily',
        title: 'Good morning!',
        body: undefined,
        subtitle: undefined,
        badge: undefined,
        sound: undefined,
        data: undefined,
        trigger: { type: 'calendar', hour: 9, minute: 0, repeats: true },
      });
    });

    it('includes all optional fields', async () => {
      mockCall.mockResolvedValueOnce({ success: true, id: 'full' });

      await notifications.schedule({
        id: 'full',
        title: 'Full Notification',
        body: 'Body text',
        subtitle: 'Subtitle',
        badge: 5,
        sound: 'default',
        data: { key: 'value' },
        trigger: { type: 'timeInterval', seconds: 60 },
      });

      expect(mockCall).toHaveBeenCalledWith('notifications', 'schedule', {
        id: 'full',
        title: 'Full Notification',
        body: 'Body text',
        subtitle: 'Subtitle',
        badge: 5,
        sound: 'default',
        data: { key: 'value' },
        trigger: { type: 'timeInterval', seconds: 60 },
      });
    });

    it('throws error when scheduling fails', async () => {
      mockCall.mockResolvedValueOnce({ success: false });

      await expect(
        notifications.schedule({
          id: 'fail',
          title: 'Fail',
          trigger: { type: 'timeInterval', seconds: 60 },
        })
      ).rejects.toThrow('Failed to schedule notification');
    });
  });

  describe('cancel', () => {
    it('cancels a notification by ID', async () => {
      mockCall.mockResolvedValueOnce({ success: true });

      await notifications.cancel('test-id');

      expect(mockCall).toHaveBeenCalledWith('notifications', 'cancel', {
        id: 'test-id',
      });
    });
  });

  describe('cancelAll', () => {
    it('cancels all notifications', async () => {
      mockCall.mockResolvedValueOnce({ success: true });

      await notifications.cancelAll();

      expect(mockCall).toHaveBeenCalledWith('notifications', 'cancelAll');
    });
  });

  describe('getPending', () => {
    it('returns empty array when no pending notifications', async () => {
      mockCall.mockResolvedValueOnce({ notifications: [] });

      const pending = await notifications.getPending();

      expect(pending).toEqual([]);
      expect(mockCall).toHaveBeenCalledWith('notifications', 'getPending');
    });

    it('returns pending notifications', async () => {
      const pendingData = [
        {
          id: 'reminder-1',
          title: 'Reminder 1',
          body: 'Body 1',
          repeats: false,
          nextTriggerDate: '2024-12-25T10:00:00Z',
        },
        {
          id: 'reminder-2',
          title: 'Reminder 2',
          repeats: true,
        },
      ];
      mockCall.mockResolvedValueOnce({ notifications: pendingData });

      const pending = await notifications.getPending();

      expect(pending).toEqual(pendingData);
      expect(pending).toHaveLength(2);
      expect(pending[0].id).toBe('reminder-1');
      expect(pending[0].nextTriggerDate).toBe('2024-12-25T10:00:00Z');
      expect(pending[1].repeats).toBe(true);
    });
  });
});
