local SettingsConfig = {
    Categories = {
        Video = {
            {
                SectionName = "Display",
                Settings = {
                    { Name = "Show FPS", Type = "Toggle", Default = false, Description = "Displays your current frames per second in the top corner of your screen." },
                    { Name = "Show Ping", Type = "Toggle", Default = false, Description = "Displays your current network latency and connection quality." },
                    { Name = "Show Performance Stats", Type = "Toggle", Default = false, Description = "Shows detailed performance metrics like GPU and CPU usage." }
                }
            },
            {
                SectionName = "Camera",
                Settings = {
                    { Name = "Field of View", Type = "Slider", Default = 70, Min = 70, Max = 120, Description = "Adjusts the camera's horizontal field of view. Higher values let you see more around you." },
                    { Name = "Camera Shake", Type = "Toggle", Default = true, Description = "Enables camera shake effects during explosions, impacts, and heavy recoil." },
                    { Name = "Dynamic FOV", Type = "Toggle", Default = false, Description = "Dynamically adjusts your Field of View based on your movement speed." }
                }
            },
            {
                SectionName = "Accessibility",
                Settings = {
                    { Name = "Colorblind Mode", Type = "Toggle", Default = false, Description = "Applies specific color filters to help players with color vision deficiencies." },
                    { Name = "High Contrast UI", Type = "Toggle", Default = false, Description = "Increases the contrast of user interface elements for better readability." },
                    { Name = "Reduce Motion", Type = "Toggle", Default = false, Description = "Reduces UI animations and camera motion effects to prevent motion sickness." }
                }
            }
        },
        Audio = {
            {
                SectionName = "Volume Mixer",
                Settings = {
                    { Name = "Master Volume", Type = "Slider", Default = 100, Min = 0, Max = 100, Description = "Adjusts the overall volume for all sounds in the game." },
                    { Name = "SFX Volume", Type = "Slider", Default = 100, Min = 0, Max = 100, Description = "Adjusts the volume of sound effects like gunfire, footsteps, and impacts." },
                    { Name = "Music Volume", Type = "Slider", Default = 100, Min = 0, Max = 100, Description = "Adjusts the volume of background music and menu tracks." },
                    { Name = "UI Volume", Type = "Slider", Default = 80, Min = 0, Max = 100, Description = "Adjusts the volume of user interface sounds like button clicks and notifications." },
                    { Name = "Ambient Volume", Type = "Slider", Default = 70, Min = 0, Max = 100, Description = "Adjusts the volume of ambient environmental sounds like wind and background noise." }
                }
            },
            {
                SectionName = "Effects",
                Settings = {
                    { Name = "3D Spatial Audio", Type = "Toggle", Default = true, Description = "Enables directional 3D audio, making it easier to pinpoint where sounds are coming from." },
                    { Name = "Hit Marker Sound", Type = "Toggle", Default = true, Description = "Plays a distinct sound effect whenever your shots land on an enemy." },
                    { Name = "Kill Sound Effect", Type = "Toggle", Default = true, Description = "Plays a rewarding sound effect whenever you successfully eliminate an opponent." }
                }
            }
        },
        Controls = {
            {
                SectionName = "Mouse & Keyboard",
                Settings = {
                    { Name = "Look Sensitivity", Type = "Slider", Default = 50, Min = 1, Max = 100, Description = "Adjusts how quickly your camera moves when looking around." },
                    { Name = "Aim Sensitivity", Type = "Slider", Default = 40, Min = 1, Max = 100, Description = "Adjusts camera sensitivity specifically while aiming down sights." }
                }
            },
            {
                SectionName = "Gamepad",
                Settings = {
                    { Name = "Controller Vibration", Type = "Toggle", Default = true, Description = "Enables haptic feedback and controller vibration for various game events." },
                    { Name = "Thumbstick Deadzone", Type = "Slider", Default = 15, Min = 0, Max = 50, Description = "Adjusts the inner deadzone of your thumbsticks. Higher values prevent stick drift." },
                    { Name = "Gamepad Look Sensitivity", Type = "Slider", Default = 60, Min = 1, Max = 100, Description = "Adjusts camera movement sensitivity specifically for gamepads." },
                    { Name = "Aim Assist", Type = "Toggle", Default = true, Description = "Slightly slows down your crosshair when hovering over a target." }
                }
            }
        },
        Cursor = {
            {
                SectionName = "Crosshair",
                Settings = {
                    { Name = "Show Crosshair", Type = "Toggle", Default = true, Description = "Displays the aiming crosshair in the center of your screen." },
                    { Name = "Dynamic Crosshair", Type = "Toggle", Default = true, Description = "Makes the crosshair expand dynamically based on movement and weapon spread." },
                    { Name = "Crosshair Scale", Type = "Slider", Default = 100, Min = 50, Max = 200, Description = "Adjusts the overall size of your in-game crosshair." },
                    { Name = "Crosshair Outline", Type = "Toggle", Default = false, Description = "Draws a dark outline around the crosshair for better visibility on bright backgrounds." }
                }
            }
        },
        Graphics = {
            {
                SectionName = "Rendering",
                Settings = {
                    { Name = "Global Illumination", Type = "Toggle", Default = true, Description = "Enables advanced realistic lighting and bounce light effects." },
                    { Name = "Dynamic Shadows", Type = "Toggle", Default = true, Description = "Enables real-time moving shadows cast by the sun, lights, and players." },
                    { Name = "Soft Shadows", Type = "Toggle", Default = true, Description = "Blurs the edges of shadows to make them look more realistic." },
                    { Name = "Ambient Occlusion", Type = "Toggle", Default = true, Description = "Adds soft contact shadows to corners, crevices, and intersecting geometry." }
                }
            },
            {
                SectionName = "Textures & Details",
                Settings = {
                    { Name = "High Res Textures", Type = "Toggle", Default = true, Description = "Uses high-resolution textures for materials and game assets." },
                    { Name = "Particle Effects", Type = "Slider", Default = 100, Min = 0, Max = 100, Description = "Adjusts the amount and intensity of visual particle effects." },
                    { Name = "Blood Effects", Type = "Toggle", Default = true, Description = "Enables blood visual effects when taking or dealing damage." }
                }
            },
            {
                SectionName = "Post-Processing",
                Settings = {
                    { Name = "Bloom Effect", Type = "Toggle", Default = true, Description = "Enables bright, glowing light effects on highly illuminated objects." },
                    { Name = "Motion Blur", Type = "Toggle", Default = false, Description = "Blurs the screen slightly during rapid camera movement for a cinematic feel." },
                    { Name = "Depth of Field", Type = "Toggle", Default = false, Description = "Slightly blurs distant objects or things out of focus for a cinematic look." },
                    { Name = "Lens Flares", Type = "Toggle", Default = true, Description = "Enables bright light reflections and lens flare effects when looking at lights." }
                }
            }
        }
    }
}

return SettingsConfig