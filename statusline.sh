#!/usr/bin/env bash
# Claude Code status line.
# Reads the status JSON from stdin and prints a single line, e.g.:
#   Opus 4.8 | Context: 84K/200K (42%) | 5h: 31% ↻2h15m | 7d: 12% ↻3d4h
#
# Schema reference (claude --version 2.x): the JSON on stdin includes
# .model.display_name, .context_window.{total_input_tokens,context_window_size,
# used_percentage} and .rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}.
# The rate_limits block only appears for Claude.ai subscription logins after
# the first API response, so the script degrades gracefully when it is absent.

input=$(cat)
esc=$(printf '\033')   # ESC byte for ANSI colors, injected into jq below

printf '%s' "$input" | jq -r --arg e "$esc" '
  # ANSI helpers (status line is rendered dimmed by the terminal).
  def R: $e + "[0m";
  def model_c: $e + "[1;36m";   # bold cyan
  def sep_c:   $e + "[2m";      # dim
  def dim_c:   $e + "[2m";      # dim (for reset countdown)
  # Pick a color for a usage percentage: green < 70, yellow < 90, else red.
  def usage_c(p): if p == null then "" elif p >= 90 then $e + "[31m"
                  elif p >= 70 then $e + "[33m" else $e + "[32m" end;
  # Compact token count: 0..999 as-is, otherwise rounded to whole K.
  def k: if . == null then "?" elif . < 1000 then (. | tostring)
         else ((. / 1000) | floor | tostring) + "K" end;
  def pct: if . == null then "?" else (. | round | tostring) end;
  # Format seconds remaining as a compact human string: 2h15m or 3d4h.
  def fmt_remaining:
    if . <= 0 then "now"
    else
      (. / 86400 | floor) as $d |
      ((. % 86400) / 3600 | floor) as $dh |
      (. / 3600 | floor) as $h |
      ((. % 3600) / 60 | floor) as $m |
      if $d > 0 then ($d | tostring) + "d" + ($dh | tostring) + "h"
      elif $h > 0 then ($h | tostring) + "h" + ($m | tostring) + "m"
      else ($m | tostring) + "m"
      end
    end;

  (.model.display_name // "Claude" | sub("^Claude "; "")) as $m
  | .context_window.total_input_tokens    as $used
  | .context_window.context_window_size   as $size
  | .context_window.used_percentage       as $cpct
  | .rate_limits.five_hour.used_percentage as $h5
  | .rate_limits.seven_day.used_percentage as $d7
  | (.rate_limits.five_hour.resets_at | if . then fromdateiso8601 - now | ceil else null end) as $h5r
  | (.rate_limits.seven_day.resets_at  | if . then fromdateiso8601 - now | ceil else null end) as $d7r
  | (sep_c + " | " + R) as $sep
  |   model_c + $m + R
    + $sep + "Context: " + ($used | k) + "/" + ($size | k)
      + " (" + usage_c($cpct) + ($cpct | pct) + "%" + R + ")"
    + (if $h5 != null then
        $sep + "5h: " + usage_c($h5) + ($h5 | pct) + "%" + R
        + (if $h5r != null then dim_c + " ↻" + ($h5r | fmt_remaining) + R else "" end)
      else "" end)
    + (if $d7 != null then
        $sep + "7d: " + usage_c($d7) + ($d7 | pct) + "%" + R
        + (if $d7r != null then dim_c + " ↻" + ($d7r | fmt_remaining) + R else "" end)
      else "" end)
'
