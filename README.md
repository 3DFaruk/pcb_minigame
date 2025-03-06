**PCB Minigame (GTAV Agents of Sabotage DLC)**

- You can use it with all game builds without any requirement.

- If you use a game build equal or higher than 3407, you can delete the stream, assets directory, and delete data_file and files lines at fxmanifest.lua

```lua
exports.pcb_minigame:startMinigame(3 --[[ solder count ]], 30 --[[ minigame seconds ]], function(success)
    print('Minigame finished with success: ' .. tostring(success))
end)
```

```lua
exports.pcb_minigame:finishMinigame()
```

https://github.com/user-attachments/assets/a87a8532-ef1a-415f-9477-758f8ec25ae5
