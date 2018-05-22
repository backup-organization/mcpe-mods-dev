import pub.hook, strformat, streams
const ModBase {.strdefine.}: string = ""
{.passL: &"{ModBase}/commands.o -lstdc++".}

import os
import sets

type
  Minecraft = distinct pointer
  UUID = distinct array[0x10, byte]

let path_whitelist = getCurrentDir() / "games" / "whitelist.txt"
let path_log = getCurrentDir() / "games" / "whitelist.log"

var whitelist = initSet[string](64)

proc checkRange(inStr: string, a, b: int): bool =
  for i in a..<b:
    if inStr[i] notin '0'..'9' and inStr[i] notin 'a'..'z': return false
  true

proc checkUUID(inStr: string): bool =
  for i in [8, 13, 18, 23]:
    if inStr[i] != '-': return false
  checkRange(inStr, 0, 8) and checkRange(inStr, 9, 13) and checkRange(inStr, 14, 18) and checkRange(inStr, 19, 23) and checkRange(inStr, 24, 36)

proc readWhitelist() =
  try:
    whitelist.clear
    for token in lines(path_whitelist):
      if token.len >= 36:
        if checkUUID(token):
          whitelist.incl(token[0..<36])
          echo "§2[Whitelist Mod] Added <" & token[0..<36] & ">"
        else:
          echo "§4[Whitelist Mod] Invalid UUID: " & token
    echo "§2[Whitelist Mod] Loaded " & $whitelist.len & " UUID."
  except IOError:
    echo("§4[Whitelist Mod] §kFailed to load whitelist(", path_whitelist, ").")

proc showUuid(ba: array[0x10, byte]): string {.noSideEffect.} =
  const hexChars = "0123456789abcdef"

  result = newString(36)
  for i in 0..<4:
    result[2*i] = hexChars[int ba[7-i] shr 4 and 0xF]
    result[2*i+1] = hexChars[int ba[7-i] and 0xF]
  result[8] = '-'
  for i in 4..<6:
    result[2*i+1] = hexChars[int ba[7-i] shr 4 and 0xF]
    result[2*i+2] = hexChars[int ba[7-i] and 0xF]
  result[13] = '-'
  for i in 6..<8:
    result[2*i+2] = hexChars[int ba[7-i] shr 4 and 0xF]
    result[2*i+3] = hexChars[int ba[7-i] and 0xF]
  result[18] = '-'
  for i in 8..<10:
    result[2*i+3] = hexChars[int ba[23-i] shr 4 and 0xF]
    result[2*i+4] = hexChars[int ba[23-i] and 0xF]
  result[23] = '-'
  for i in 10..<16:
    result[2*i+4] = hexChars[int ba[23-i] shr 4 and 0xF]
    result[2*i+5] = hexChars[int ba[23-i] and 0xF]

proc `$`(uuid: UUID) : string =
  ((array[0x10, byte])uuid).showUuid

proc activeWhitelist(minecraft: Minecraft) {. importc: "_ZN9Minecraft17activateWhitelistEv" .}

var mc: Minecraft = nil

hook "_ZN9Minecraft12initCommandsEv":
  proc initCommands(minecraft: Minecraft) {. refl .} =
    mc = minecraft

hook "_ZNK9Whitelist9isAllowedERKN3mce4UUIDERKSs":
  proc isAllowed(list: pointer, uuid: var UUID, text: var cstring): bool =
    if $uuid in whitelist:
      echo "§2[Whitelist Mod] Allowed " & $uuid
      return true
    echo "§4[Whitelist Mod] Denied " & $uuid
    let f = open(path_log, fmAppend, 4096)
    defer: f.close()
    f.writeLine($uuid)
    return false

proc mod_init(): void {. cdecl, exportc .} =
  readWhitelist()

proc mod_set_server(_: pointer): void {. cdecl, exportc .} =
  mc.activeWhitelist

proc setupCommands(registry: pointer) {.importc.}
proc processCommand(sub, inString: cstring): cstring {. cdecl, exportc .} =
  let inStr = $inString
  case $sub:
  of "add":
    if checkUUID(inStr):
      if inStr[0..<36] in whitelist:
        return "§4[Whitelist Mod] Duplicated UUID: " & inStr
      let stream = newFileStream(path_whitelist, fmAppend)
      defer: stream.close()
      stream.writeLine(inStr)
      whitelist.incl(inStr[0..<36])
      "§2[Whitelist Mod] Allowed " & inStr
    else:
      "§4[Whitelist Mod] Not a UUID: " & inStr
  of "reload":
    readWhitelist()
    "§2[Whitelist Mod] Reloaded"
  else:
    "§2[Whitelist Mod] Unexpected Command"

hook "_ZN10SayCommand5setupER15CommandRegistry":
  proc setupCommand(registry: pointer) {.refl.} =
    setupCommands(registry)
