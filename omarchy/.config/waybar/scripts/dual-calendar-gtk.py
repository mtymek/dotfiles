#!/usr/bin/env python3
"""
Dual Month Calendar Popup for Waybar using GTK
Shows current and next month side by side
"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk
import calendar
from datetime import datetime, timedelta

# Event Horizon theme colors
COLORS = {
    'background': '#1c1e26',
    'foreground': '#fadad1',
    'accent': '#26bbd9',
    'today': '#e95678',
    'weekday': '#fab795',
    'weekend': '#6c6f93',
    'header': '#ffead3',
    'border': '#26bbd9',
}

class DualMonthCalendar(Gtk.Window):
    def __init__(self):
        super().__init__()
        
        self.set_title("Calendar")
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_border_width(20)
        
        # Current date
        self.today = datetime.now()
        self.current_month = self.today.month
        self.current_year = self.today.year
        
        # Calculate next month
        if self.current_month == 12:
            self.next_month = 1
            self.next_year = self.current_year + 1
        else:
            self.next_month = self.current_month + 1
            self.next_year = self.current_year
        
        self.setup_ui()
        self.apply_styling()
        
        # Close on escape
        self.connect('key-press-event', self.on_key_press)
        self.connect('focus-out-event', self.on_focus_out)
        self.connect('button-press-event', self.on_button_press)
        
    def setup_ui(self):
        # Main container
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(main_box)
        
        # Navigation bar
        nav_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        main_box.pack_start(nav_box, False, False, 0)
        
        # Previous button
        prev_btn = Gtk.Button(label='◀')
        prev_btn.connect('clicked', self.on_prev_month)
        nav_box.pack_start(prev_btn, False, False, 0)
        
        # Today button
        today_btn = Gtk.Button(label='Today')
        today_btn.connect('clicked', self.on_today)
        nav_box.pack_start(today_btn, False, False, 0)
        
        # Close button
        close_btn = Gtk.Button(label='✕')
        close_btn.connect('clicked', lambda x: self.destroy())
        nav_box.pack_end(close_btn, False, False, 0)
        
        # Next button
        next_btn = Gtk.Button(label='▶')
        next_btn.connect('clicked', self.on_next_month)
        nav_box.pack_end(next_btn, False, False, 0)
        
        # Calendars container
        cals_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        main_box.pack_start(cals_box, True, True, 0)
        
        # Separator style
        separator = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        
        # Create calendar widgets
        self.cal1 = self.create_calendar_widget()
        self.cal2 = self.create_calendar_widget()
        
        cals_box.pack_start(self.cal1, True, True, 0)
        cals_box.pack_start(separator, False, False, 0)
        cals_box.pack_start(self.cal2, True, True, 0)
        
        # Initial render
        self.update_calendars()
        
    def create_calendar_widget(self):
        """Create a custom calendar display"""
        frame = Gtk.Frame()
        frame.set_shadow_type(Gtk.ShadowType.NONE)
        
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        frame.add(vbox)
        
        # Month header
        header = Gtk.Label()
        header.set_markup('<span font_weight="bold" size="large"></span>')
        vbox.pack_start(header, False, False, 5)
        
        # Days grid
        grid = Gtk.Grid()
        grid.set_column_homogeneous(True)
        grid.set_row_homogeneous(True)
        grid.set_column_spacing(5)
        grid.set_row_spacing(5)
        vbox.pack_start(grid, True, True, 0)
        
        frame.header = header
        frame.grid = grid
        return frame
        
    def update_calendars(self):
        self.render_calendar(self.cal1, self.current_year, self.current_month)
        self.render_calendar(self.cal2, self.next_year, self.next_month)
        
    def render_calendar(self, cal_widget, year, month):
        # Update header
        month_name = datetime(year, month, 1).strftime('%B %Y')
        cal_widget.header.set_markup(f'<span font_weight="bold" size="large" color="{COLORS["header"]}">{month_name}</span>')
        
        # Clear grid
        for child in cal_widget.grid.get_children():
            cal_widget.grid.remove(child)
        
        # Day headers
        days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        for i, day in enumerate(days):
            color = COLORS['weekend'] if i >= 5 else COLORS['weekday']
            label = Gtk.Label()
            label.set_markup(f'<span color="{color}" weight="bold">{day}</span>')
            cal_widget.grid.attach(label, i, 0, 1, 1)
        
        # Calendar days
        cal = calendar.Calendar(firstweekday=0)
        month_days = cal.monthdayscalendar(year, month)
        
        for week_idx, week in enumerate(month_days):
            for day_idx, day in enumerate(week):
                if day == 0:
                    label = Gtk.Label(label='')
                else:
                    is_today = (day == self.today.day and 
                               month == self.today.month and 
                               year == self.today.year)
                    
                    is_weekend = day_idx >= 5
                    
                    if is_today:
                        markup = f'<span color="{COLORS["today"]}" weight="bold" underline="single">{day}</span>'
                    elif is_weekend:
                        markup = f'<span color="{COLORS["weekend"]}">{day}</span>'
                    else:
                        markup = f'<span color="{COLORS["foreground"]}">{day}</span>'
                    
                    label = Gtk.Label()
                    label.set_markup(markup)
                
                cal_widget.grid.attach(label, day_idx, week_idx + 1, 1, 1)
        
        cal_widget.show_all()
        
    def apply_styling(self):
        css_provider = Gtk.CssProvider()
        css = f"""
        window {{
            background-color: {COLORS['background']};
        }}
        button {{
            background-color: {COLORS['background']};
            color: {COLORS['accent']};
            border: 1px solid {COLORS['accent']};
            padding: 5px 10px;
            border-radius: 4px;
        }}
        button:hover {{
            background-color: {COLORS['accent']};
            color: {COLORS['background']};
        }}
        frame {{
            background-color: {COLORS['background']};
        }}
        separator {{
            background-color: {COLORS['border']};
            min-width: 2px;
        }}
        label {{
            color: {COLORS['foreground']};
        }}
        """
        css_provider.load_from_data(css.encode())
        
        screen = Gdk.Screen.get_default()
        style_context = Gtk.StyleContext()
        style_context.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        
    def on_prev_month(self, button):
        if self.current_month == 1:
            self.current_month = 12
            self.current_year -= 1
        else:
            self.current_month -= 1
            
        if self.next_month == 1:
            self.next_month = 12
            self.next_year -= 1
        else:
            self.next_month -= 1
            
        self.update_calendars()
        
    def on_next_month(self, button):
        if self.current_month == 12:
            self.current_month = 1
            self.current_year += 1
        else:
            self.current_month += 1
            
        if self.next_month == 12:
            self.next_month = 1
            self.next_year += 1
        else:
            self.next_month += 1
            
        self.update_calendars()
        
    def on_today(self, button):
        self.today = datetime.now()
        self.current_month = self.today.month
        self.current_year = self.today.year
        
        if self.current_month == 12:
            self.next_month = 1
            self.next_year = self.current_year + 1
        else:
            self.next_month = self.current_month + 1
            self.next_year = self.current_year
            
        self.update_calendars()
        
    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()
        return False
        
    def on_focus_out(self, widget, event):
        self.destroy()
        return False
        
    def on_button_press(self, widget, event):
        # Check if click is outside window
        allocation = widget.get_allocation()
        if event.x < 0 or event.x > allocation.width or event.y < 0 or event.y > allocation.height:
            self.destroy()
        return False

def main():
    win = DualMonthCalendar()
    win.connect('destroy', Gtk.main_quit)
    win.show_all()
    Gtk.main()

if __name__ == '__main__':
    main()
