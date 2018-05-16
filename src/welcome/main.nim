import pub.hook
import pub.interp

import os
import json
import tables
import streams
import strutils

type
  Player = distinct pointer

proc name(player: Player) : var cstring {. importc: "_ZNK6Entity10getNameTagEv" .}

var
  execWhenJoin : seq[string] = @[]
  execWhenLeft : seq[string] = @[]
  execMap = {"CodeHz": @["op CodeHz"]}.toTable

proc readCfg(filename: string) =
  if existsFile(filename):
    try:
      let filestream = newFileStream(filename, fmRead, 4096)
      defer: filestream.close()
      let parsed = parseJson(filestream, filename)
      if parsed.kind != JObject:
        return
      if parsed.hasKey("join") and parsed["join"].kind == JArray:
        for item in parsed["join"]:
          execWhenJoin.add(item.getStr)
        echo("join: \n\t", execWhenJoin.join("\n\t"))
      if parsed.hasKey("left") and parsed["left"].kind == JArray:
        for item in parsed["left"]:
          execWhenLeft.add(item.getStr)
        echo("left: \n\t", execWhenLeft.join("\n\t"))
      if parsed.hasKey("map") and parsed["map"].kind == JObject:
        execMap.clear
        echo "map: "
        for key, value in parsed["map"]:
          if value.kind != JArray:
            continue
          var temp : seq[string] = @[]
          for item in value:
            temp.add(item.getStr)
          execMap.add(key, temp)
          echo("\t", key, ":\n\t\t", temp.join("\n\t\t"))
      echo "§2[Welcome Mod]Loaded"
    except IOError:
      echo "§4[Welcome Mod]§kI/O Exception"
    except JsonParsingError:
      echo "§4[Welcome Mod]§kJSON parsed failed"
    except FieldError:
      echo "§4[Welcome Mod]§kJSON parsed failed(Field's type mismatch)"
    except:
      echo "§4[Welcome Mod]§kUnknown error"
  else:
    echo("§4[Welcome Mod]§kNo config found(", filename,"), Fallback to default config: ", execMap)

hook "_ZNK9minecraft3api15PlayerInterface23handlePlayerJoinedEventER6Player":
  proc onPlayerJoin(self: pointer, player: Player): void {. refl .} =
    let name = $player.name
    echo(name, " Joined.")
    for item in execWhenJoin:
      ExecCommand(item.replace("{{player}}", name))
    if execMap.hasKey(name):
      for item in execMap[name]:
        ExecCommand(item.replace("{{player}}", name))

hook "_ZNK9minecraft3api15PlayerInterface21handlePlayerLeftEventER6Player":
  proc onPlayerLeft(self: pointer, player: Player): void {. refl .} =
    let name = $player.name
    echo(name, " Left.")
    for item in execWhenLeft:
      ExecCommand(item.replace("{{player}}", name))

proc mod_init(): void {. cdecl, exportc .} =
  echo "Welcome Mod Loaded"
  let cfg = getCurrentDir() / "games" / "welcome.json"
  readCfg(cfg)