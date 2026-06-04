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
