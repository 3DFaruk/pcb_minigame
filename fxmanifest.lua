fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'pcb_minigame'
version '1.0.0'
author '3DFaruk'
repository 'https://github.com/3DFaruk/pcb_minigame'

client_script 'client.lua'

files {
    'assets/data/dlc24-2_sounds.dat54.rel',
    'assets/audiodirectory/*.awc',
}

data_file 'AUDIO_WAVEPACK' 'assets/audiodirectory'
data_file 'AUDIO_SOUNDDATA' 'assets/data/dlc24-2_sounds.dat'