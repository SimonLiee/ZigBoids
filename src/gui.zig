const std = @import("std");
const rl = @import("raylib");

const Menu = struct {
    rect: rl.Rectangle,
    title: [:0]const u8,
    titleSize: f32,
    checkBoxes: []CheckBox,
    padding: f32,
    visible: bool,
    visibilityButton: rl.Rectangle,
    pressed: bool,

    pub fn update(self: *Menu) void {
        self.checkClick();

        var currY = self.rect.y + self.padding;
        currY += self.titleSize + self.padding;
        for (self.checkBoxes) |*checkBox| {
            checkBox.update(self.rect.x + self.padding, currY);
            currY += checkBox.size;
            currY += self.padding;
        }
        self.rect.height = currY - self.rect.y;
    }

    fn checkClick(self: *Menu) void {
        if (rl.checkCollisionPointRec(rl.getMousePosition(), self.visibilityButton)) {
            if (rl.isMouseButtonReleased(rl.MouseButton.left) and self.pressed) {
                self.visible = !self.visible;
                std.debug.print("Vissible \n", .{});
            }
            if (rl.isMouseButtonDown(rl.MouseButton.left)) {
                std.debug.print("Pressed \n", .{});
                self.pressed = true;
            } else {
                self.pressed = false;
            }
        }
    }

    pub fn draw(self: *Menu) void {
        rl.drawRectangleRec(self.visibilityButton, rl.Color.gray);
        rl.drawTextPro(
            rl.getFontDefault() catch |err| std.debug.panic("Panic at error: {any}\n", .{err}),
            "V",
            rl.Vector2.init(self.visibilityButton.x + 12, self.visibilityButton.y + 12.5),
            rl.Vector2.init(@as(f32, @floatFromInt(rl.measureText("V", 25))) / 2, 12.5),
            if (self.visible) 180 else 0,
            25,
            0,
            rl.Color.black,
        );

        if (!self.visible) return;
        rl.drawRectangleRec(self.rect, rl.Color.gray);
        rl.drawText(
            self.title,
            @intFromFloat(self.rect.x + self.padding),
            @intFromFloat(self.rect.y + self.padding),
            @intFromFloat(self.titleSize),
            rl.Color.black,
        );
        for (self.checkBoxes) |checkBox| {
            checkBox.draw();
        }
    }
};

const CheckBox = struct {
    name: [:0]const u8,
    size: f32,
    rect: rl.Rectangle,
    pressed: bool,
    checked: *bool,

    fn draw(self: CheckBox) void {
        rl.drawRectangleRec(self.rect, rl.Color.white);
        rl.drawRectangleLinesEx(self.rect, 3, rl.Color.black);

        if (self.checked.*) {
            rl.drawCircleV(
                rl.Vector2.init(self.rect.x + self.rect.width / 2, self.rect.y + self.rect.width / 2),
                self.size / 4,
                rl.Color.black,
            );
        }

        rl.drawText(
            self.name,
            @intFromFloat(self.rect.x + self.size + 5),
            @intFromFloat(self.rect.y),
            @intFromFloat(self.size),
            rl.Color.black,
        );
    }

    fn update(self: *CheckBox, x: f32, y: f32) void {
        self.rect = rl.Rectangle{ .x = x, .y = y, .height = self.size, .width = self.size };
        self.checkMouseClick();
    }

    fn checkMouseClick(self: *CheckBox) void {
        if (rl.checkCollisionPointRec(rl.getMousePosition(), self.rect)) {
            if (rl.isMouseButtonReleased(rl.MouseButton.left) and self.pressed) {
                self.checked.* = !self.checked.*;
            }
            if (rl.isMouseButtonDown(rl.MouseButton.left)) {
                self.pressed = true;
            } else {
                self.pressed = false;
            }
        }
    }
};

const Options = struct {
    bounds: bool,
    separation: bool,
    alignment: bool,
    cohesion: bool,
    respawn: bool,
    zoids: bool,
};

pub var options = Options{
    .bounds = true,
    .separation = true,
    .alignment = true,
    .cohesion = true,
    .respawn = false,
    .zoids = true,
};

var checkboxes = blk: {
    const len = @typeInfo(Options).@"struct".fields.len;
    var cb: [len]CheckBox = undefined;
    for (@typeInfo(Options).@"struct".fields, 0..len) |field, i| {
        cb[i] = CheckBox{
            .name = field.name,
            .size = 25,
            .rect = rl.Rectangle.init(0, 0, 0, 0),
            .pressed = false,
            .checked = &@field(options, field.name),
        };
    }
    break :blk cb;
};

pub var mainMenu = Menu{
    .rect = rl.Rectangle.init(10, 35, 180, 400),
    .checkBoxes = &checkboxes,
    .padding = 8,
    .title = "Options",
    .titleSize = 30,
    .visible = true,
    .visibilityButton = rl.Rectangle.init(10, 10, 25, 25),
    .pressed = false,
};
