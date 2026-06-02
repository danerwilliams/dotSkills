def lang(p):
  if p == null then "n/a"
  elif (p|test("\\.tsx$")) then "tsx"
  elif (p|test("\\.ts$"))  then "ts"
  elif (p|test("\\.jsx$")) then "jsx"
  elif (p|test("\\.js$"))  then "js"
  elif (p|test("\\.(css|scss|less)$")) then "css"
  elif (p|test("\\.json$")) then "json"
  elif (p|test("\\.md$"))   then "md"
  elif (p|test("\\.(ya?ml)$")) then "yaml"
  elif (p|test("\\.sql$"))  then "sql"
  elif (p|test("\\.prisma$")) then "prisma"
  elif (p|test("\\.py$"))   then "py"
  elif (p|test("\\.go$"))   then "go"
  elif (p|test("\\.rs$"))   then "rust"
  else "other" end;
. + {lang: (lang(.path // null))}
