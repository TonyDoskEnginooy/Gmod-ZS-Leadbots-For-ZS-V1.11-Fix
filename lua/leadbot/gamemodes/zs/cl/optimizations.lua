-- These default GMod hooks waste my precious bot resources
hook.Remove("PreDrawHalos", "PropertiesHover")
hook.Remove("DrawOverlay", "DragNDropPaint")
hook.Remove("DrawOverlay", "DrawNumberScratch")