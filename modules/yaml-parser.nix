{ lib }:
let
  inherit (lib)
    splitString
    filter
    foldl'
    stringLength
    substring
    hasPrefix
    hasSuffix
    removePrefix
    removeSuffix
    concatStringsSep
    concatMapStringsSep
    head
    tail
    length
    elemAt
    match
    ;

  # Parse a YAML string into a Nix attribute set
  # This handles the subset of YAML commonly used in Taskfiles
  parseYAML = yamlString:
    let
      # Split into lines
      lines = splitString "\n" yamlString;

      # Process lines into structured data
      result = parseLines lines 0 0 { };
    in
    result.value;

  # Helper: Count leading spaces in a string
  countLeadingSpaces = str:
    let
      len = stringLength str;
      countSpaces' = n:
        if n >= len then n
        else if substring n 1 str == " " then countSpaces' (n + 1)
        else n;
    in
    countSpaces' 0;

  # Helper: Trim leading and trailing whitespace
  trim = str:
    let
      # Remove leading spaces
      trimStart' = s:
        if s == "" then s
        else if hasPrefix " " s then trimStart' (removePrefix " " s)
        else s;

      # Remove trailing spaces
      trimEnd' = s:
        if s == "" then s
        else if hasSuffix " " s then trimEnd' (removeSuffix " " s)
        else s;
    in
    trimEnd' (trimStart' str);

  # Helper: Remove quotes from a string if present
  removeQuotes = str:
    let
      trimmed = trim str;
      hasDoubleQuotes = hasPrefix "\"" trimmed && hasSuffix "\"" trimmed;
      hasSingleQuotes = hasPrefix "'" trimmed && hasSuffix "'" trimmed;
    in
    if hasDoubleQuotes || hasSingleQuotes
    then substring 1 (stringLength trimmed - 2) trimmed
    else trimmed;

  # Helper: Parse a scalar value (string, number, boolean, null)
  parseScalar = str:
    let
      trimmed = trim str;
      unquoted = removeQuotes trimmed;
    in
    if trimmed == "null" || trimmed == "~" || trimmed == "" then null
    else if trimmed == "true" || trimmed == "yes" || trimmed == "True" || trimmed == "Yes" then true
    else if trimmed == "false" || trimmed == "no" || trimmed == "False" || trimmed == "No" then false
    # Try to parse as number
    else if match "[0-9]+" trimmed != null then
      lib.toInt trimmed
    else if match "[0-9]+\\.[0-9]+" trimmed != null then
      # For floats, keep as string since Nix doesn't have native float type
      unquoted
    else unquoted;

  # Helper: Check if a line is empty or a comment
  isEmptyOrComment = line:
    let
      trimmed = trim line;
    in
    trimmed == "" || hasPrefix "#" trimmed;

  # Helper: Find the first occurrence of a character in a string
  # Returns the index of the first occurrence, or -1 if not found
  indexOf = char: str:
    let
      len = stringLength str;
      find' = n:
        if n >= len then -1
        else if substring n 1 str == char then n
        else find' (n + 1);
    in
    find' 0;

  # Parse a list of lines starting from a given index
  # Returns: { value = <parsed data>; nextIndex = <index after this block>; }
  parseLines = lines: startIdx: baseIndent: context:
    let
      numLines = length lines;

      # Process lines iteratively
      processLines = idx: currentValue:
        if idx >= numLines then
          { value = currentValue; nextIndex = idx; }
        else
          let
            line = elemAt lines idx;
            indent = countLeadingSpaces line;
            trimmedLine = trim line;
          in
          # Skip empty lines and comments
          if isEmptyOrComment line then
            processLines (idx + 1) currentValue

          # If indentation decreased, we're done with this block
          else if idx > startIdx && indent < baseIndent then
            { value = currentValue; nextIndex = idx; }

          # Handle array items (lines starting with "- ")
          else if hasPrefix "- " trimmedLine then
            let
              itemContent = removePrefix "- " trimmedLine;

              # Check if this is an inline value or a nested structure
              hasColon = match ".*:.*" itemContent != null;

              parsed = if hasColon then
                # Array item is a map, parse it
                let
                  colonIdx = indexOf ":" itemContent;

                  # Ensure colonIdx is valid
                  validColonIdx = if colonIdx < 0
                    then throw "indexOf failed to find ':' in array item: ${itemContent}"
                    else colonIdx;

                  key = trim (substring 0 validColonIdx itemContent);
                  value = trim (substring (validColonIdx + 1) (stringLength itemContent - validColonIdx - 1) itemContent);

                  # Check if value is empty (multiline) or inline
                  nestedResult = if value == "" then
                    parseLines lines (idx + 1) (indent + 2) { }
                  else
                    { value = parseScalar value; nextIndex = idx + 1; };
                in
                {
                  value = currentValue ++ [ ({ ${key} = nestedResult.value; }) ];
                  nextIndex = nestedResult.nextIndex;
                }
              else if itemContent == "" then
                # Empty array item, check next lines for nested content
                let
                  nestedResult = parseLines lines (idx + 1) (indent + 2) { };
                in
                {
                  value = currentValue ++ [ nestedResult.value ];
                  nextIndex = nestedResult.nextIndex;
                }
              else
                # Simple scalar array item
                {
                  value = currentValue ++ [ (parseScalar itemContent) ];
                  nextIndex = idx + 1;
                };
            in
            processLines parsed.nextIndex parsed.value

          # Handle key-value pairs
          else if match ".*:.*" trimmedLine != null then
            let
              # Find the colon position
              colonPos = indexOf ":" trimmedLine;

              # Ensure colonPos is valid (should always be >= 0 since we matched for ":")
              validColonPos = if colonPos < 0
                then throw "indexOf failed to find ':' in line: ${trimmedLine}"
                else colonPos;

              key = trim (substring 0 validColonPos trimmedLine);
              valueStr = trim (substring (validColonPos + 1) (stringLength trimmedLine - validColonPos - 1) trimmedLine);

              # Determine if this is a multiline value or nested structure
              parsed =
                # Check for pipe character (multiline string)
                if valueStr == "|" || valueStr == "|-" || valueStr == "|+" then
                  let
                    # Collect all subsequent lines with greater indentation
                    collectMultiline = i: acc:
                      if i >= numLines then acc
                      else
                        let
                          nextLine = elemAt lines i;
                          nextIndent = countLeadingSpaces nextLine;
                          nextTrimmed = trim nextLine;
                        in
                        if isEmptyOrComment nextLine then
                          collectMultiline (i + 1) (acc ++ [ "" ])
                        else if nextIndent > indent then
                          collectMultiline (i + 1) (acc ++ [ (substring indent (stringLength nextLine - indent) nextLine) ])
                        else
                          { lines = acc; nextIndex = i; };

                    multilineResult = collectMultiline (idx + 1) [];
                    multilineValue = concatStringsSep "\n" multilineResult.lines;
                  in
                  {
                    value = currentValue // { ${key} = multilineValue; };
                    nextIndex = multilineResult.nextIndex;
                  }

                # Empty value means nested structure
                else if valueStr == "" then
                  let
                    # Parse nested structure
                    nestedResult = parseLines lines (idx + 1) (indent + 2)
                      # Check if next line is an array item
                      (if (idx + 1 < numLines) && (hasPrefix "- " (trim (elemAt lines (idx + 1))))
                       then []  # Start with empty list for arrays
                       else {});  # Start with empty set for maps
                  in
                  {
                    value = currentValue // { ${key} = nestedResult.value; };
                    nextIndex = nestedResult.nextIndex;
                  }

                # Inline value
                else
                  {
                    value = currentValue // { ${key} = parseScalar valueStr; };
                    nextIndex = idx + 1;
                  };
            in
            processLines parsed.nextIndex parsed.value

          # Unknown format, skip
          else
            processLines (idx + 1) currentValue;
    in
    processLines startIdx context;

in
{
  inherit parseYAML;

  # Parse a YAML file (takes a path)
  parseYAMLFile = path: parseYAML (builtins.readFile path);
}
