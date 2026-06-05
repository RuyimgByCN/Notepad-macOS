import Foundation
import Testing
@testable import NotepadMacCore

@Test func extractsBashFunctionListSymbolsUsingUpstreamMetadata() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("bash.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        #!/usr/bin/env bash
        function build_app() {
            echo build
        }

        deploy_app() {
            echo deploy
        }

        if [[ -n "$CI" ]]; then
            echo ci
        fi
        """,
        languageName: "bash",
        definition: definition
    )

    #expect(definition.displayName == "Bash")
    #expect(symbols.map(\.name) == ["build_app", "deploy_app"])
    #expect(symbols.map(\.kind) == [.function, .function])
    #expect(symbols.map(\.line) == [2, 6])
}

@Test func extractsJavaScriptFunctionListSymbolsUsingUpstreamMetadata() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("javascript.js.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        class NotebookView {
            constructor(model) {
                this.model = model;
            }

            static createDefault() {
                return new NotebookView({});
            }

            async refreshList() {
                return await loadItems();
            }
        }

        function bootstrapApp(root) {
            return root;
        }

        window.Notepad.openFile = function(path) {
            return path;
        };

        const saveDraft = function(name) {
            return name;
        };

        if (enabled) {
            while (busy) {
                tick();
            }
        }
        """,
        languageName: "javascript.js",
        definition: definition
    )

    #expect(definition.displayName == "JavaScript")
    #expect(definition.identifier == "javascript_function")
    #expect(definition.classRangePatterns.isEmpty == false)
    #expect(symbols.map(\.name) == [
        "NotebookView",
        "constructor",
        "createDefault",
        "refreshList",
        "bootstrapApp",
        "openFile",
        "saveDraft"
    ])
    #expect(symbols.map(\.kind) == [
        .type,
        .function,
        .function,
        .function,
        .function,
        .function,
        .function
    ])
    #expect(symbols.map(\.line) == [1, 2, 6, 10, 15, 19, 23])
}

@Test func extractsPHPFunctionListSymbolsUsingUpstreamMetadata() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("php.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        <?php
        final readonly class NotebookController {
            public function renderList(array $items): string {
                return "";
            }

            protected static function &cachedItems() {
                static $items = [];
                return $items;
            }
        }

        interface Renderable {
            public function render(): string;
        }

        trait TracksChanges {
            private function recordChange(string $name): void {
            }
        }

        function format_title(string $title): string {
            return trim($title);
        }

        $callback = function ($value) {
            return $value;
        };
        """,
        languageName: "php",
        definition: definition
    )

    #expect(definition.displayName == "PHP - Personal Home Page / PHP Hypertext Preprocessor")
    #expect(definition.identifier == "php_syntax")
    #expect(definition.classRangePatterns.isEmpty == false)
    #expect(definition.functionPatterns.isEmpty == false)
    #expect(symbols.map(\.name) == [
        "NotebookController",
        "renderList",
        "cachedItems",
        "Renderable",
        "render",
        "TracksChanges",
        "recordChange",
        "format_title"
    ])
    #expect(symbols.map(\.kind) == [
        .type,
        .function,
        .function,
        .type,
        .function,
        .type,
        .function,
        .function
    ])
    #expect(symbols.map(\.line) == [2, 3, 7, 13, 14, 17, 18, 22])
}

@Test func extractsRubyFunctionListSymbolsUsingUpstreamMetadata() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("ruby.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        class Notebook
          def initialize(title)
            @title = title
          end

          def render
            @title
          end
        end

        class DraftStore
          def save
          end
        end

        def normalize_title(value)
          value.strip
        end
        """,
        languageName: "ruby",
        definition: definition
    )

    #expect(definition.displayName == "Ruby")
    #expect(definition.identifier == "ruby_syntax")
    #expect(definition.classRangePatterns.isEmpty == false)
    #expect(definition.functionPatterns.isEmpty == false)
    #expect(symbols.map(\.name) == [
        "Notebook",
        "initialize",
        "render",
        "DraftStore",
        "save",
        "normalize_title"
    ])
    #expect(symbols.map(\.kind) == [
        .type,
        .function,
        .function,
        .type,
        .function,
        .function
    ])
    #expect(symbols.map(\.line) == [1, 2, 6, 11, 12, 16])
}

private func upstreamFunctionListURL(_ fileName: String) -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "notepad-plus-plus/PowerEditor/installer/functionList/\(fileName)")
}

@Test func extractsGoFunctions() {
    let goCode = """
    package main

    import "fmt"

    type Server struct { port int }
    type Handler interface { Handle(r *Request) }

    func NewServer(port int) *Server {
        return &Server{port: port}
    }

    func (s *Server) Start() error {
        fmt.Println("starting")
        return nil
    }

    func helper() {}
    """
    let symbols = FunctionListExtractor.extract(from: goCode, languageName: "go", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("Server"))
    #expect(names.contains("Handler"))
    #expect(names.contains("NewServer"))
    #expect(names.contains("Start"))
    #expect(names.contains("helper"))
}

@Test func extractsKotlinFunctions() {
    let kotlinCode = """
    class UserService {
        fun createUser(name: String): User {
            return User(name)
        }
    }

    data class User(val name: String)

    suspend fun fetchData(): List<String> = emptyList()

    object Config {
        fun load() {}
    }
    """
    let symbols = FunctionListExtractor.extract(from: kotlinCode, languageName: "kotlin", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("UserService"))
    #expect(names.contains("createUser"))
    #expect(names.contains("User"))
    #expect(names.contains("fetchData"))
    #expect(names.contains("Config"))
}

@Test func extractsLuaFunctions() {
    let luaCode = """
    function greet(name)
        print("Hello " .. name)
    end

    local function helper()
        return 42
    end

    local myModule = {}
    myModule.process = function(x)
        return x * 2
    end
    """
    let symbols = FunctionListExtractor.extract(from: luaCode, languageName: "lua", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("greet"))
    #expect(names.contains("helper"))
}

@Test func extractsSQLObjects() {
    let sqlCode = """
    CREATE FUNCTION calculate_tax(amount DECIMAL)
    RETURNS DECIMAL AS $$
    BEGIN
        RETURN amount * 0.1;
    END;
    $$ LANGUAGE plpgsql;

    CREATE OR REPLACE PROCEDURE update_user(user_id INT)
    LANGUAGE plpgsql AS $$
    BEGIN
        UPDATE users SET updated_at = NOW() WHERE id = user_id;
    END;
    $$;

    CREATE VIEW active_users AS
    SELECT * FROM users WHERE active = true;

    CREATE TABLE orders (id SERIAL PRIMARY KEY);
    """
    let symbols = FunctionListExtractor.extract(from: sqlCode, languageName: "sql", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("calculate_tax"))
    #expect(names.contains("update_user"))
    #expect(names.contains("active_users"))
    #expect(names.contains("orders"))
}

@Test func extractsTypeScriptSymbols() {
    let tsCode = """
    export interface ApiResponse<T> {
        data: T;
        status: number;
    }

    export class UserController {
        async getUser(id: string): Promise<User> {
            return fetch(`/users/${id}`).then(r => r.json());
        }

        private validateId(id: string): boolean {
            return id.length > 0;
        }
    }

    export async function fetchAll(): Promise<void> {}

    const transform = (input: string): string => input.toUpperCase();
    """
    let symbols = FunctionListExtractor.extract(from: tsCode, languageName: "typescript", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("ApiResponse"))
    #expect(names.contains("UserController"))
    #expect(names.contains("fetchAll"))
}

@Test func extractsPowerShellSymbols() {
    let code = """
    function Get-UserInfo {
        param($userId)
        return $userId
    }

    filter Convert-ToUpper {
        $_.ToUpper()
    }

    class ApiClient {
        [string]$BaseUrl
    }
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "powershell", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("Get-UserInfo") || names.contains("UserInfo"))
    #expect(names.contains("Convert-ToUpper") || names.contains("ToUpper") || symbols.contains { $0.name.contains("Convert") })
    #expect(names.contains("ApiClient"))
}

@Test func extractsPerlSymbols() {
    let code = """
    package MyApp::Utils;

    sub validate_email {
        my ($email) = @_;
        return $email =~ /@/;
    }

    sub format_date {
        return localtime();
    }
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "perl", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("MyApp::Utils"))
    #expect(names.contains("validate_email"))
    #expect(names.contains("format_date"))
}

@Test func extractsMarkdownHeadings() {
    let code = """
    # Introduction

    ## Getting Started

    ### Installation

    ## Configuration

    # Conclusion
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "markdown", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("Introduction"))
    #expect(names.contains("Getting Started"))
    #expect(names.contains("Installation"))
    #expect(names.contains("Configuration"))
    #expect(names.contains("Conclusion"))
}

@Test func extractsVisualBasicSymbols() {
    let code = """
    Public Class UserService
        Public Function GetUser(id As Integer) As User
            Return Nothing
        End Function

        Private Sub ValidateInput(name As String)
        End Sub
    End Class

    Module Helpers
        Public Function FormatDate() As String
            Return Date.Now.ToString()
        End Function
    End Module
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "vb", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("UserService"))
    #expect(names.contains("GetUser"))
    #expect(names.contains("ValidateInput"))
    #expect(names.contains("Helpers"))
}

@Test func extractsInnoSetupSymbols() {
    let code = """
    [Setup]
    AppName=MyApp
    AppVersion=1.0

    [Code]
    function InitializeSetup(): Boolean;
    begin
        Result := True;
    end;

    procedure CurStepChanged(CurStep: TSetupStep);
    begin
        // nothing
    end;

    [Files]
    Source: "myapp.exe"; DestDir: "{app}"
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "inno", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("InitializeSetup"))
    #expect(names.contains("CurStepChanged"))
    #expect(names.contains("Setup") || names.contains("Code") || names.contains("Files"))
}

@Test func extractsSASMacrosAndFunctions() {
    let code = """
    %macro compute_stats(dataset, var);
        proc means data=&dataset;
        run;
    %mend compute_stats;

    function log_transform(x);
        return(log(x));
    endsub;

    %macro format_output;
        proc print;
    %mend;
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "sas", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("compute_stats"))
    #expect(names.contains("log_transform"))
    #expect(names.contains("format_output"))
}

@Test func extractsAssemblyLabels() {
    let code = """
    section .text
    global _start

    _start:
        mov eax, 1
        call print_msg
        ret

    print_msg:
        mov ebx, 1
        ret

    error_handler:
        xor eax, eax
        ret
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "asm", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("_start"))
    #expect(names.contains("print_msg"))
    #expect(names.contains("error_handler"))
}

@Test func extractsAutoItFunctions() {
    let code = """
    Func _Main()
        _DisplayMessage("Hello")
    EndFunc

    Func _DisplayMessage($sMsg)
        MsgBox(0, "Title", $sMsg)
    EndFunc

    Func _ValidateInput($sInput)
        Return StringLen($sInput) > 0
    EndFunc
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "autoit", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("_Main"))
    #expect(names.contains("_DisplayMessage"))
    #expect(names.contains("_ValidateInput"))
}

@Test func extractsMakefileTargets() {
    let code = """
    .PHONY: all clean test

    all: main.o utils.o
    \t$(CC) -o myapp main.o utils.o

    main.o: main.c
    \t$(CC) -c main.c

    clean:
    \trm -f *.o myapp

    install: all
    \tcp myapp /usr/local/bin
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "makefile", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("all"))
    #expect(names.contains("main.o"))
    #expect(names.contains("clean"))
    #expect(names.contains("install"))
}

@Test func extractsGDScriptSymbols() {
    let code = """
    class_name MyNode

    class Inner:
        func inner_method():
            pass

    func _ready():
        pass

    func process_input(event):
        return event
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "gdscript", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("Inner"))
    #expect(names.contains("_ready"))
    #expect(names.contains("process_input"))
}

@Test func extractsRakuSymbols() {
    let code = """
    class Animal {
        method breathe() { }
    }

    module Utils {
        sub format-date($date) { return $date.Str }
    }

    sub MAIN(Str $name) { say "Hello, $name" }
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "raku", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("Animal"))
    #expect(names.contains("Utils"))
    #expect(names.contains("MAIN"))
}

@Test func extractsCOBOLParagraphs() {
    let code = """
    IDENTIFICATION DIVISION.
    PROGRAM-ID. MyProgram.

    PROCEDURE DIVISION.
    000-MAIN-LOGIC.
        PERFORM 100-INITIALIZE.
        PERFORM 200-PROCESS.
        STOP RUN.

    100-INITIALIZE.
        MOVE ZERO TO WS-COUNTER.

    200-PROCESS SECTION.
        PERFORM 210-READ-DATA.

    210-READ-DATA.
        READ INPUT-FILE.
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "cobol", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains { $0.contains("MAIN") || $0.contains("000") })
    #expect(names.contains { $0.contains("INITIALIZE") || $0.contains("100") })
    #expect(names.contains { $0.contains("PROCESS") || $0.contains("200") })
}

@Test func extractsHollywoodFunctions() {
    let code = """
    Function SetupWindow()
        SetFormStyle(#METAL)
    EndFunction

    Function OnMenuSelect(id)
        Switch id
        Case 1: Quit()
        EndSwitch
    EndFunction
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "hollywood", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("SetupWindow"))
    #expect(names.contains("OnMenuSelect"))
}

@Test func extractsKRLFunctions() {
    let code = """
    DEF MainProg()
        homePos()
        BAS(#INITMOV, 0)
    END

    DEFFCT REAL CalculateDist(p1:IN, p2:IN)
        RETURN SQRT(...)
    ENDFCT

    GLOBAL DEF SafeMove(target:IN)
        LIN target
    END
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "krl", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("MainProg"))
    #expect(names.contains("CalculateDist"))
    #expect(names.contains("SafeMove"))
}

@Test func extractsSinumerikPrograms() {
    let code = """
    %_N_MAIN_MPF
    ; Main machining program
    G0 X0 Y0

    %_N_DRILL_CYCLE_SPF
    ; Drilling subroutine
    G81 Z-10

    %_N_FINISH_SPF
    G70
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "sinumerik", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("MAIN_MPF"))
    #expect(names.contains("DRILL_CYCLE_SPF"))
    #expect(names.contains("FINISH_SPF"))
}

@Test func extractsNppExecScriptsAndLabels() {
    let code = """
    ::Build Project
    npp_save
    cd "$(CURRENT_DIRECTORY)"
    cmd /c build.bat
    goto :done

    :done
    echo Build complete

    ::Run Tests
    cmd /c run_tests.bat
    :error
    echo Failed
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "nppexec", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains { $0.contains("Build") })
    #expect(names.contains { $0.contains("Run") || $0.contains("Tests") })
    #expect(names.contains { $0.contains("done") || $0.contains("error") })
}

@Test func extractsFortran77Functions() {
    let code = [
        "C     This is a comment",
        "      SUBROUTINE MYSUB(X, Y)",
        "      REAL X, Y",
        "      RETURN",
        "      END",
        "C     Another comment",
        "* also a comment",
        "      INTEGER FUNCTION MYFUNC(N)",
        "      INTEGER N",
        "      RETURN",
        "      END",
        "      SUBROUTINE HELPER()",
        "      END",
    ].joined(separator: "\n")
    let symbols = FunctionListExtractor.extract(from: code, languageName: "fortran77", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("MYSUB"))
    #expect(names.contains("MYFUNC"))
    #expect(names.contains("HELPER"))
}

@Test func extractsObjectiveCSymbols() {
    let code = """
    @interface MyViewController : UIViewController
    @end

    @implementation MyViewController
    - (void)viewDidLoad {
        [super viewDidLoad];
    }

    + (instancetype)sharedController {
        return nil;
    }

    - (NSString *)titleForRow:(NSInteger)row {
        return @"";
    }
    @end

    @protocol MyDelegate
    @end
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "objective-c", definition: nil)
    let names = symbols.map(\.name)
    let kinds = symbols.map(\.kind)
    #expect(names.contains("MyViewController"))
    #expect(names.contains("MyDelegate"))
    #expect(kinds.contains(.type))
    #expect(names.contains(where: { $0.hasPrefix("viewDidLoad") || $0.hasPrefix("sharedController") || $0.hasPrefix("titleForRow") }))
}

@Test func extractsCOBOLFreeParagraphs() {
    let code = """
    IDENTIFICATION DIVISION.
    PROGRAM-ID. HELLO.

    PROCEDURE DIVISION.
        MAIN-LOGIC SECTION.
        PROCESS-INPUT.
            DISPLAY "Hello".
            STOP RUN.
        VALIDATE-DATA SECTION.
        CHECK-FIELD.
            CONTINUE.
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "cobol-free", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains(where: { $0.hasPrefix("MAIN-LOGIC") || $0.hasPrefix("VALIDATE-DATA") }))
    #expect(!names.isEmpty)
}

@Test func extractsElixirSymbols() {
    let code = """
    defmodule MyApp.Server do
      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts)
      end

      defp handle_state(state) do
        state
      end
    end

    defmodule MyApp.Worker do
      def perform(job) do
        :ok
      end
    end
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "elixir", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("MyApp.Server"))
    #expect(names.contains("MyApp.Worker"))
    #expect(names.contains("start_link"))
    #expect(names.contains("perform"))
}

@Test func extractsErlangFunctions() {
    let code = """
    -module(calculator).
    -export([add/2, subtract/2, multiply/2]).

    add(X, Y) ->
        X + Y.

    subtract(X, Y) ->
        X - Y.

    multiply(X, Y) ->
        X * Y.

    internal_helper(X) ->
        X * 2.
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "erlang", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("add"))
    #expect(names.contains("subtract"))
    #expect(names.contains("multiply"))
    #expect(names.contains("internal_helper"))
}

@Test func extractsOCamlSymbols() {
    let code = """
    type point = { x: float; y: float }

    type shape =
      | Circle of float
      | Rectangle of float * float

    let distance p1 p2 =
      sqrt ((p2.x -. p1.x) ** 2.0 +. (p2.y -. p1.y) ** 2.0)

    let rec factorial n =
      if n <= 1 then 1 else n * factorial (n - 1)

    let area = function
      | Circle r -> Float.pi *. r *. r
      | Rectangle (w, h) -> w *. h
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "ocaml", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("point"))
    #expect(names.contains("shape"))
    #expect(names.contains("distance"))
    #expect(names.contains("factorial"))
}

@Test func extractsFSharpSymbols() {
    let code = """
    type Vector2D = { X: float; Y: float }

    type Shape =
        | Circle of float
        | Rectangle of float * float

    let add x y = x + y

    let rec fib n =
        if n <= 1 then n else fib (n-1) + fib (n-2)

    module MathUtils =
        let square x = x * x
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "fsharp", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("Vector2D"))
    #expect(names.contains("Shape"))
    #expect(names.contains("add"))
    #expect(names.contains("fib"))
}

@Test func extractsHTMLSymbols() {
    let code = """
    <!DOCTYPE html>
    <html>
    <head><title>Test Page</title></head>
    <body>
    <h1>Introduction</h1>
    <p id="overview">Some text here.</p>
    <h2>Getting Started</h2>
    <div id="setup">Setup instructions</div>
    <h3>Step One</h3>
    </body>
    </html>
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "html", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("Introduction"))
    #expect(names.contains("Getting Started"))
    #expect(names.contains("Step One"))
    #expect(names.contains("overview"))
    #expect(names.contains("setup"))
}

@Test func extractsDartSymbols() {
    let code = """
    class Animal {
        String name;
        Animal(this.name);
        void speak() {
            print('...');
        }
    }

    abstract class Shape {
        double area();
    }

    void main() {
        var a = Animal('Dog');
    }

    Future<String> fetchData() async {
        return 'data';
    }
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "dart", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("Animal"))
    #expect(names.contains("Shape"))
}

@Test func extractsJuliaSymbols() {
    let code = """
    struct Point
        x::Float64
        y::Float64
    end

    abstract type Shape end

    mutable struct Circle <: Shape
        radius::Float64
    end

    function area(c::Circle)
        π * c.radius^2
    end

    function distance(p1::Point, p2::Point)
        sqrt((p2.x - p1.x)^2 + (p2.y - p1.y)^2)
    end

    macro assert_positive(x)
        :($x > 0 || error("Not positive"))
    end
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "julia", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("Point"))
    #expect(names.contains("Shape"))
    #expect(names.contains("Circle"))
    #expect(names.contains("area"))
    #expect(names.contains("distance"))
    #expect(names.contains("assert_positive"))
}

@Test func extractsCMakeSymbols() {
    let code = """
    cmake_minimum_required(VERSION 3.20)
    project(MyApp)

    function(add_component name sources)
        add_library(${name} STATIC ${sources})
        target_include_directories(${name} PUBLIC include)
    endfunction()

    macro(setup_target target)
        target_compile_features(${target} PRIVATE cxx_std_17)
        set_target_properties(${target} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    endmacro()

    add_component(core src/core.cpp)
    setup_target(core)
    """
    let symbols = FunctionListExtractor.extract(from: code, languageName: "cmake", definition: nil)
    let names = symbols.map(\.name)
    #expect(names.contains("add_component"))
    #expect(names.contains("setup_target"))
}
