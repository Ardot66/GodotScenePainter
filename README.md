# Godot Scene Painter
Godot Scene Painter adds basic text painting functionality for development directly into the Godot 2D scene editor with zero runtime cost. Just press the new paint button in the toolbar, and you can:
- Leave notes for yourself or teammates.
- Sketch out ideas right where you want them.
- Plan out levels in advance.
- Do a bunch of other stuff I can't think of off the top of my head.

## Painting
https://github.com/user-attachments/assets/3750ca7a-cee1-4da0-a0ba-0bb685576a6d

## Typing
https://github.com/user-attachments/assets/1ce306fd-13ca-4d70-95c5-efacbc83042b

## Usage
First, install the plugin either through the Godot asset library, or by copying the addons/scene_painter folder of this repository into your addons folder. Don't forget to enable the plugin!

Upon opening the 2D scene editor, you should see four new buttons:

<img width="122" height="31" alt="image" src="https://github.com/user-attachments/assets/1d6ea167-84a6-48f0-8632-a835f4eafd76" />

They have the following functions:
1. Toggle the visibility of the painting canvas. (Note that you can't paint or edit text when the canvas is invisible!)
2. Toggle paintbrush mode, where you can click and drag anywhere in the scene editor to paint. Hold RMB to erase instead.
3. Toggle text mode, where you can click anywhere to create and edit text boxes. The contents of text boxes can be modified in the inspector.
4. Edit your brush settings. Opens a small window with a few options like brush size and color.

For more information, everything has a tooltip describing what it does in detail.

## Settings
All settings exist under addons/scene_painter in the Project Settings menu.

| Setting | Description |
| - | - |
| default_max_line_width | The default maximum line width in pixels that will be applied to newly created text boxes |
| default_font_size | The default font size of text boxes |
| default_font_color | The default font color of text boxes |
| data_folder | The root folder in which .paint.tres files will be stored. By default, this is res://, which makes .paint.tres files store alongside their linked .tscn file. If you wish to store these files in a separate directory to avoid bloating your filesystem, simply set this to any other folder. |
| paint_scale | The scale of pixels in scene paintings. A higher scale means that each pixel in a painting appears to take up a larger area. Generally, this should be set so that all paintings are easy to read, but aren't super high resolution compared to the scale that you're working at (as that can have editor performance implications) |

## Technical Details
- All paintings are stored in a separate file alongside each scene by default, so that it is easy to manage them, and so that they don't bloat your scene files.
- This tool is intended entirely for development use; paintings and text will never appear in your game while it's running. It is highly recommended to exclude all .paint.tres files during exporting, as they won't see any use.
- Very large drawings may result in godot running out of memory, and can cause long scene opening and saving times. They will also result in large .paint.tres files. Text does not have the same restrictions, so prefer text over painting whenever possible.
- .paint.tres files can be safely deleted from the Godot file dock even while their respective .tscn file is open. This will automatically clear corresponding paintings from the scene dock.
- .paint.tres files will automatically move with their corresponding .tscn files if the .tscn file is moved or deleted within Godot's file dock.
- .paint.tres files will stick around even if this plugin is disabled or deleted. Just delete them if you don't need them anymore.

## Roadmap
There's definitely a lot more this plugin could do. Modern art programs (and even older ones) have way more features than just painting. These include:
- Selections and moving
- Configurable brushes
- Bucket filling
- Copying
- Multiple layers

None of these are implemented yet, as I don't really need them for my particular use case, and this tool isn't really meant to be a professional art tool anyways. However, if you want or need any of these improvements, please open an issue, or even better, submit a PR with your own implementation!
