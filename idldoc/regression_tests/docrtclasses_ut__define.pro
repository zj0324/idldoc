; docformat = 'rst'

;+
; Basic IDLdoc run of on save files.
;-
function docrtclasses_ut::test_basic
  compile_opt strictarr

  idldoc, root=filepath('classes', root=self.root), $
          output=filepath('classes-docs', root=self.root), $
          title='Testing OOP class files', $
          subtitle='Basic test', $
          /silent, n_warnings=nWarnings, error=error, $
          log_file=filepath('idldoc.log', subdir='classes-docs', root=self.root)
          
  assert, error eq 0, 'failed with error ' + !error_state.msg
  
  mg_open_url, 'file://' + filepath('index.html', subdir='classes-docs', root=self.root)
  
  assert, nWarnings eq 0, 'failed with warnings'
  
  return, 1
end


;+
; Define instance variables.
;-
pro docrtclasses_ut__define
  compile_opt strictarr
  
  define = { DOCrtClasses_ut, inherits DOCrtTestCase }
end