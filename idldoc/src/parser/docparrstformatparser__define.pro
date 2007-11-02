; docformat = 'rst'

;+
; Handles parsing of the rst (restructured text) style comment blocks.
;-


;+
; Parse the lines from a tag; simply removes the tag and passes along the rest.
; 
; :Params:
;    lines : in, out, required, type=strarr
;-
function docparrstformatparser::_parseTag, lines
  compile_opt strictarr
  
  mylines = lines
  pos = stregex(lines[0], '^[[:space:]]*:[[:alpha:]_]+:[[:space:]]*', length=len)
  mylines[0] = strmid(lines[0], pos + len)
  
  return, mylines                                           
end  
         
                                            
;+
; Handles one tag in a file's comments.
; 
; :Params:
;    tag : in, required, type=string
;       rst tag, i.e. returns, params, keywords, etc.
;    lines : in, required, type=strarr
;       lines of raw text for that tag
;
; :Keywords:
;    file : in, required, type=object
;       file tree object 
;    markup_parser : in, required, type=object
;       markup parser object
;-
pro docparrstformatparser::_handleFileTag, tag, lines, $
                                           file=file, $
                                           markup_parser=markupParser
  compile_opt strictarr
  
  case strlowcase(tag) of
    'properties': begin        
        file->getProperty, is_class=isClass, class=class
        if (~isClass) then begin
          self.system->warning, 'property not allowed non-class definition file'
        endif                              
        
        ; find number of spaces that properties' names are indented
        l = 1L
        nameIndent = -1L
        while (l lt n_elements(lines) && nameIndent eq -1L) do begin 
          nameIndent = stregex(lines[1], '[[:alnum:]_$]')          
        endwhile
        
        ; must indent property names
        if (nameIndent lt 1) then begin
          self.system->warning, 'invalid properties syntax'
          return
        endif              

        ; find properties' names lines (ignore first line, first property starts 
        ; on the line after :Properties:)        
        propLines = lines[1:*]
        re = string(format='(%"^[ ]{%d}([[:alnum:]_$]+)")', nameIndent)        
        propertyNamesStart = stregex(propLines, re, $
                                     /subexpr, length=propertyNamesLength)
        propertyDefinitionLines = where(propertyNamesStart[1, *] ne -1L, nProperties)
        
        ; add each property
        for p = 0L, nProperties - 1L do begin
         propertyName = strmid(propLines[propertyDefinitionLines[p]], $
                               propertyNamesStart[1, propertyDefinitionLines[p]], $
                               propertyNamesLength[1, propertyDefinitionLines[p]])
         property = class->addProperty(propertyName)         
         propertyDefinitionEnd = p eq nProperties - 1L $
                                   ? n_elements(propLines) - 1L $
                                   : propertyDefinitionLines[p + 1L] - 1L
         if (propertyDefinitionLines[p] + 1 le propertyDefinitionEnd) then begin
           comments = propLines[propertyDefinitionLines[p] + 1L:propertyDefinitionEnd] 
           property->setProperty, comments=markupParser->parse(comments)        
         endif  
        endfor                     
      end
    
    'hidden': file->setProperty, is_hidden=1B
    'private': file->setProperty, is_private=1B
    
    'examples': file->setProperty, examples=markupParser->parse(self->_parseTag(lines))
    
    'author': file->setProperty, author=markupParser->parse(self->_parseTag(lines))
    'copyright': file->setProperty, copyright=markupParser->parse(self->_parseTag(lines))
    'history': file->setProperty, history=markupParser->parse(self->_parseTag(lines))
    'version': file->setProperty, version=markupParser->parse(self->_parseTag(lines))
    
    else: begin
        file->getProperty, basename=basename
        self.system->warning, 'unknown tag ' + tag + ' in file ' + basename
      end
  endcase
end


;+
; Handles one tag in a routine's comments.
; 
; :Params:
;    tag : in, required, type=string
;       rst tag, i.e. returns, params, keywords, etc.
;    lines : in, required, type=strarr
;       lines of raw text for that tag
;
; :Keywords:
;    routine : in, required, type=object
;       routine tree object 
;    markup_parser : in, required, type=object
;       markup parser object
;-
pro docparrstformatparser::_handleRoutineTag, tag, lines, routine=routine, $
                                              markup_parser=markupParser
  compile_opt strictarr
  
  case strlowcase(tag) of
    'abstract': routine->setProperty, is_abstract=1B
    'author': routine->setProperty, author=markupParser->parse(self->_parseTag(lines))
    'bugs': begin
        routine->setProperty, bugs=markupParser->parse(self->_parseTag(lines))
        self.system->createBugEntry, routine
      end      
    'categories': begin
        comments = self->_parseTag(lines)
        categories = strtrim(strsplit(strjoin(comments), ',', /extract), 2)
        for i = 0L, n_elements(categories) - 1L do begin
          if (categories[i] ne '') then begin
            routine->addCategory, categories[i]
            self.system->createCategoryEntry, categories[i], routine
          endif
        endfor
      end
    'copyright': routine->setProperty, copyright=markupParser->parse(self->_parseTag(lines))
    'customer_id': routine->setProperty, customer_id=markupParser->parse(self->_parseTag(lines))
    'examples': routine->setProperty, examples=markupParser->parse(self->_parseTag(lines))
        
    'fields': begin
        routine->getProperty, file=file
        file->getProperty, is_class=isClass, class=class
        if (~isClass) then begin
          self.system->warning, 'field not allowed non-class definition file'
        endif
                                          
        ; find number of spaces that fields' names are indented
        l = 1L
        nameIndent = -1L
        while (l lt n_elements(lines) && nameIndent eq -1L) do begin 
          nameIndent = stregex(lines[1], '[[:alnum:]_$]')          
        endwhile
        
        ; must indent fields names
        if (nameIndent lt 1) then begin
          self.system->warning, 'invalid fields syntax'
          return
        endif              

        ; find fields' names lines (ignore first line, first field starts 
        ; on the line after :Fields:)        
        fieldLines = lines[1:*]
        re = string(format='(%"^[ ]{%d}([[:alnum:]_$]+)")', nameIndent)        
        fieldNamesStart = stregex(fieldLines, re, $
                                  /subexpr, length=fieldNamesLength)
        fieldDefinitionLines = where(fieldNamesStart[1, *] ne -1L, nFields)
        
        ; add each property
        for f = 0L, nFields - 1L do begin
         fieldName = strmid(fieldLines[fieldDefinitionLines[f]], $
                            fieldNamesStart[1, fieldDefinitionLines[f]], $
                            fieldNamesLength[1, fieldDefinitionLines[f]])
         field = class->addField(fieldName, /get_only)
         
         fieldDefinitionEnd = f eq nFields - 1L $
                                ? n_elements(fieldLines) - 1L $
                                : fieldDefinitionLines[f + 1L] - 1L
         if (fieldDefinitionLines[f] + 1L le fieldDefinitionEnd) then begin
           if (obj_valid(field)) then begin
             comments = fieldLines[fieldDefinitionLines[f] + 1L:fieldDefinitionEnd] 
             field->setProperty, name=fieldName, comments=markupParser->parse(comments)
           endif else begin
             self.system->warning, 'invalid field ' + fieldName
           endelse        
         endif  
        endfor             
      end
    
    'file_comments': begin
        routine->getProperty, file=file
        file->setProperty, comments=markupParser->parse(self->_parseTag(lines))
      end
    'hidden': routine->setProperty, is_hidden=1
    'hidden_file': begin
        routine->getProperty, file=file
        file->setProperty, is_hidden=1B
      end
    'history': routine->setProperty, history=markupParser->parse(self->_parseTag(lines))
    'inherits':   ; not used any more       
    'keywords': self->_handleArgumentTag, lines, routine=routine, $
                                          markup_parser=markupParser, /keyword     
    'obsolete': begin
        routine->setProperty, is_obsolete=1B
        self.system->createObsoleteEntry, routine
      end          
    'params': self->_handleArgumentTag, lines, routine=routine, $
                                        markup_parser=markupParser    
    'post': routine->setProperty, post=markupParser->parse(self->_parseTag(lines))
    'pre': routine->setProperty, pre=markupParser->parse(self->_parseTag(lines))
    'private': routine->setProperty, is_private=1B
    'private_file': begin
        routine->getProperty, file=file
        file->setProperty, is_private=1B
      end
    'requires': begin        
        requires = self->_parseTag(lines)
        
        ; look for an IDL version
        for i = 0L, n_elements(requires) - 1L do begin
          version = stregex(lines[i], '[[:digit:].]+', /extract)
          if (version ne '') then break
        endfor
         
        ; if you have a real version then check in with system
        if (version ne '') then begin
          self.system->checkRequiredVersion, version, routine
        endif
        
        routine->setProperty, requires=markupParser->parse(requires)
      end
    'restrictions': routine->setProperty, restrictions=markupParser->parse(self->_parseTag(lines))
    'returns': routine->setProperty, returns=markupParser->parse(self->_parseTag(lines))
    'todo': begin
        routine->setProperty, todo=markupParser->parse(self->_parseTag(lines))
        self.system->createTodoEntry, routine
      end
    'uses': routine->setProperty, uses=markupParser->parse(self->_parseTag(lines))
    'version': routine->setProperty, version=markupParser->parse(self->_parseTag(lines))
    else: begin
        routine->getProperty, name=name
        self.system->warning, 'unknown tag ' + tag + ' in routine ' + name
      end
  endcase
end



;+
; Handles a tag with attributes (i.e. {} enclosed arguments like in param or 
; keyword).
; 
; :Params:
;    lines : in, required, type=strarr
;       lines of raw text for that tag
;
; :Keywords:
;    routine : in, required, type=object
;       routine tree object 
;    markup_parser : in, required, type=object
;       markup parser object
;    keyword : in, optional, type=boolean
;       set to indicate the tag is a keyword
;-
pro docparrstformatparser::_handleArgumentTag, lines, $
                                                  routine=routine, $
                                                  markup_parser=markupParser, $
                                                  keyword=keyword
  compile_opt strictarr
  
  ; find params/keywords
  
  ; find number of spaces that properties' names are indented
  l = 1L
  nameIndent = -1L
  while (l lt n_elements(lines) && nameIndent eq -1L) do begin 
    nameIndent = stregex(lines[1], '[[:alnum:]_$]')          
  endwhile
        
  ; must indent property names
  if (nameIndent lt 1) then begin
    self.system->warning, 'invalid properties syntax'
    return
  endif              

  ; find properties' names lines (ignore first line, first property starts 
  ; on the line after :Properties:)        
  paramLines = lines[1:*]
  re = string(format='(%"^[ ]{%d}([[:alnum:]_$]+)")', nameIndent)        
  paramNamesStart = stregex(paramLines, re, $
                            /subexpr, length=paramNamesLength)
  paramDefinitionLines = where(paramNamesStart[1, *] ne -1L, nParams)

  routine->getProperty, name=routineName
  tag = keyword_set(keyword) ? 'keyword' : 'param'
  
  ; add each property
  for p = 0L, nParams - 1L do begin
   paramName = strmid(paramLines[paramDefinitionLines[p]], $
                      paramNamesStart[1, paramDefinitionLines[p]], $
                      paramNamesLength[1, paramDefinitionLines[p]])
   param = keyword_set(keyword) $
             ? routine->getKeyword(paramName, found=found) $
             : routine->getParameter(paramName, found=found)
             
   if (~found) then begin     
     msg = string(format='(%"%s %s not found in %s")', tag, paramName, routineName)
     self.system->warning, msg       
     continue                      
   endif         
   
   headerLine = paramLines[paramDefinitionLines[p]]
   colonPos = strpos(headerLine, ':')
   if (colonPos ne -1L) then begin
     attributes = strsplit(strmid(headerLine, colonPos + 1L), ',', /extract)
     for a = 0L, n_elements(attributes) - 1L do begin
      self->_handleAttribute, param, strtrim(attributes[a], 2), routine=routine
     endfor
   endif
   
   paramDefinitionEnd = p eq nParams - 1L $
                          ? n_elements(paramLines) - 1L $
                          : paramDefinitionLines[p + 1L] - 1L
   if (paramDefinitionLines[p] + 1 le paramDefinitionEnd) then begin
     comments = paramLines[paramDefinitionLines[p] + 1L:paramDefinitionEnd] 
     param->setProperty, comments=markupParser->parse(comments)        
   endif  
  endfor                       
end


;+
; 
;-
pro docparrstformatparser::_handleAttribute, param, attribute, routine=routine
  compile_opt strictarr
  
  param->getProperty, name=paramName
  routine->getProperty, name=routineName  
  
  result = strsplit(attribute, '=', /extract)
  attributeName = result[0]
  attributeValue = (n_elements(result) gt 1) ? result[1] : ''
  case attributeName of
    'in': param->setProperty, is_input=1
    'out': param->setProperty, is_output=1
    'optional': param->setProperty, is_optional=1
    'required': param->setProperty, is_required=1
    'private': param->setProperty, is_private=1
    'hidden': param->setProperty, is_hidden=1
    'obsolete': param->setProperty, is_obsolete=1

    'type': param->setProperty, type=attributeValue
    'default': param->setProperty, default_value=attributeValue
    else: begin
        self.system->warning, $
          'unknown argument attribute ' + attributeName $
            + ' for argument' + paramName + ' in ' + routineName           
      end
  endcase  
end
                                                  
;+
; Handles parsing of a comment block using rst syntax. 
;
; :Params:
;    lines : in, required, type=strarr
;       all lines of the comment block
; :Keywords:
;    routine : in, required, type=object
;       routine tree object 
;    markup_parser : in, required, type=object
;       markup parser object
;-
pro docparrstformatparser::parseRoutineComments, lines, routine=routine,  $
                                                 markup_parser=markupParser
  compile_opt strictarr
  
  ; find tags enclosed by ":"s that are the first non-whitespace character on 
  ; the line
  tagLocations = where(stregex(lines, '^[[:space:]]*:[[:alpha:]_]+:') ne -1L, nTags)
  
  ; parse normal comments
  tagsStart = nTags gt 0 ? tagLocations[0] : n_elements(lines)
  if (tagsStart ne 0) then begin
    comments = markupParser->parse(lines[0:tagsStart - 1L])
    routine->setProperty, comments=comments
  endif  
  
  ; go through each tag
  for t = 0L, nTags - 1L do begin
    tagStart = tagLocations[t]
    tagFull = stregex(lines[tagStart], ':[[:alpha:]_]+:', /extract)
    tag = strmid(tagFull, 1, strlen(tagFull) - 2L)
    tagEnd = t eq nTags - 1L $
               ? n_elements(lines) - 1L $
               : tagLocations[t + 1L] - 1L
    self->_handleRoutineTag, tag, lines[tagStart:tagEnd], $
                             routine=routine, markup_parser=markupParser
  endfor
end


pro docparrstformatparser::parseFileComments, lines, file=file,  $
                                              markup_parser=markupParser
  compile_opt strictarr
  
  ; find tags enclosed by ":"s that are the first non-whitespace character on 
  ; the line
  re = '^[[:space:]]*:[[:alpha:]_]+:'
  tagLocations = where(stregex(lines, re) ne -1L, nTags)
  
  ; parse normal comments
  tagsStart = nTags gt 0 ? tagLocations[0] : n_elements(lines)
  if (tagsStart ne 0) then begin
    comments = markupParser->parse(lines[0:tagsStart - 1L])
    file->setProperty, comments=comments
  endif  
  
  ; go through each tag
  for t = 0L, nTags - 1L do begin
    tagStart = tagLocations[t]
    tagFull = stregex(lines[tagStart], ':[[:alpha:]_]+:', /extract)
    tag = strmid(tagFull, 1, strlen(tagFull) - 2L)
    tagEnd = t eq nTags - 1L $
               ? n_elements(lines) - 1L $
               : tagLocations[t + 1L] - 1L
    self->_handleFileTag, tag, lines[tagStart:tagEnd], $
                          file=file, markup_parser=markupParser
  endfor  
end


pro docparrstformatparser::parseOverviewComments, lines, system=system, $
                                                  markup_parser=markupParser
  compile_opt strictarr

  ; find tags enclosed by ":"s that are the first non-whitespace character on 
  ; the line
  re = '^[[:space:]]*:[[:alpha:]_]+:'
  tagLocations = where(stregex(lines, re) ne -1L, nTags)
  
  ; parse normal comments
  tagsStart = nTags gt 0 ? tagLocations[0] : n_elements(lines)
  if (tagsStart ne 0) then begin
    comments = markupParser->parse(lines[0:tagsStart - 1L])
    system->setProperty, overview_comments=comments
  endif

  ; go through each tag
  for t = 0L, nTags - 1L do begin
    tagStart = tagLocations[t]
    re = ':[[:alpha:]_]+:'
    fullTag = stregex(lines[tagStart], re, /extract)
    tag = strmid(fullTag, 1, strlen(fullTag) - 2L)
    tagEnd = t eq nTags - 1L $
               ? n_elements(lines) - 1L $
               : tagLocations[t + 1L] - 1L
    tagLines = self->_parseTag(lines[tagStart:tagEnd])
    
    case strlowcase(tag) of
      'dirs': begin
          ; TODO: implement this tag
        end
      else: begin
          system->getProperty, overview=overview
          system->warning, 'unknown tag ' + tag + ' in overview file ' + overview
        end
    endcase
  endfor
end


;+
; Define instance variables.
;- 
pro docparrstformatparser__define
  compile_opt strictarr

  define = { DOCparRstFormatParser, inherits DOCparFormatParser }
end
