---
description: Guidelines for clean, maintainable C# code (functional patterns, abstraction). For ASP.NET Core API projects also apply dotnet-api.md.
globs: *.cs
alwaysApply: false
---

Role Definition:
 - C# Language Expert
 - Software Architect
 - Code Quality Specialist

General:
  Description: >
    C# code should be written to maximize readability, maintainability, and correctness
    while minimizing complexity and coupling. Prefer functional patterns and immutable
    data where appropriate, and keep abstractions simple and focused.
  Requirements:
    - Write clear, self-documenting code
    - Keep abstractions simple and focused
    - Minimize dependencies and coupling
    - Use modern C# features appropriately
    - Apply Clean Architecture (dependency rule, layers) and SOLID principles where appropriate

Type Definitions:
  - Prefer records for data types:
      ```csharp
      // Good: Immutable data type with value semantics
      public sealed record CustomerDto(string Name, Email Email);
      
      // Avoid: Class with mutable properties
      public class Customer
      {
          public string Name { get; set; }
          public string Email { get; set; }
      }
      ```
  - Prefer sealed to prevent unnecessary inheritance; make classes sealed by default:
      ```csharp
      // Good: Sealed by default – no unintended inheritance
      public sealed class OrderProcessor
      {
          // Implementation
      }
      
      // Only unsealed when inheritance is specifically designed for
      public abstract class Repository<T>
      {
          // Base implementation
      }
      ```
  - Do not use primary constructors on regular classes; use a traditional constructor instead. Primary constructors are idiomatic for `record` / `record struct` types, but on classes they obscure field declarations and make dependency injection less explicit:
      ```csharp
      // Good: Traditional constructor on a class – fields are visible and explicit
      public sealed class OrderProcessor
      {
          private readonly IOrderRepository _repository;
          private readonly ILogger<OrderProcessor> _logger;

          public OrderProcessor(IOrderRepository repository, ILogger<OrderProcessor> logger)
          {
              _repository = repository;
              _logger = logger;
          }
      }

      // Good: Primary constructor on a record – idiomatic and concise
      public sealed record OrderCreatedEvent(OrderId OrderId, DateTime CreatedAt);

      // Avoid: Primary constructor on a class – hides field declarations,
      // parameters are mutable captures, not readonly fields
      public sealed class OrderProcessor(IOrderRepository repository, ILogger<OrderProcessor> logger)
      {
          // repository and logger are not readonly fields; they are captured parameters
      }
      ```
  - Use value objects to avoid primitive obsession:
      ```csharp
      // Good: Strong typing with value objects
      public sealed record OrderId(Guid Value)
      {
          public static OrderId New() => new(Guid.NewGuid());
          public static OrderId From(string value) => new(Guid.Parse(value));
      }
      
      // Avoid: Primitive types for identifiers
      public class Order
      {
          public Guid Id { get; set; }  // Primitive obsession
      }
      ```

Properties and modifiers:
  - Prefer immutable properties; if a setter is needed use init-only or private set:
      ```csharp
      // Good: No setter, or init / private set
      public sealed record Dto(string Id, string Name);
      public class Entity
      {
          public Guid Id { get; init; }
          public string Name { get; private set; }
      }
      
      // Avoid: Public setter when not required
      public class Entity
      {
          public Guid Id { get; set; }
          public string Name { get; set; }
      }
      ```
  - **Init-only when it fits:** Any property that is only assigned at object creation (constructor body, object initializer, `with` expression) and must not change afterward **must use `init`**, not public `set`. Reserve `set` (or `private set`) for members that are intentionally mutated after construction. Default: if you would never assign outside the construction phase, use `init`.
      ```csharp
      // Good: “fixed after build” surface – init + object initializer / ctor
      public sealed class CreateOrderRequest
      {
          public required Guid CustomerId { get; init; }
          public required IReadOnlyList<OrderLine> Lines { get; init; }
          public string? Notes { get; init; }
      }

      public sealed class CachedConfig
      {
          public string ConnectionString { get; init; } = "";
          public TimeSpan Ttl { get; init; } = TimeSpan.FromMinutes(5);
      }
      ```
      ```csharp
      // Avoid: public set when the value is never reassigned after creation
      public sealed class CreateOrderRequest
      {
          public Guid CustomerId { get; set; }
          public IReadOnlyList<OrderLine> Lines { get; set; } = [];
      }
      ```
  - Use conventional modifier order (access modifier first, then static/readonly etc.):
      ```csharp
      // Good: public static
      public static class Helpers { }
      public static async Task RunAsync() { }
      
      // Avoid: static public
      static public class Helpers { }
      ```
  - Use minimal visibility; prefer internal, private, or protected when public is not required:
      ```csharp
      // Good: Only public surface is exposed
      internal sealed class OrderProcessor
      {
          private readonly IRepository _repo;
          internal OrderProcessor(IRepository repo) => _repo = repo;
          public Task<Order> GetAsync(Guid id) => _repo.GetAsync(id);
      }
      
      // Avoid: Everything public
      public sealed class OrderProcessor
      {
          public IRepository Repo;
          public OrderProcessor(IRepository repo) { Repo = repo; }
          public Task<Order> GetAsync(Guid id) => Repo.GetAsync(id);
      }
      ```

Object initializers:
  - **Prefer object initializers** when creating instances of types with multiple settable or `init` properties: one creation site, property names visible at the call site, and correct ordering is not fragile. Use collection/indexer initializers together with object initializers when building nested structures.
      ```csharp
      // Good: object initializer – clear which value maps to which member
      var request = new CreateOrderRequest
      {
          CustomerId = customerId,
          Lines = orderLines,
          Notes = optionalNotes
      };

      var options = new JsonSerializerOptions
      {
          PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
          WriteIndented = true
      };
      ```
  - **Avoid** long positional constructor argument lists when an object initializer would read better, and avoid creating an object then assigning many properties in separate statements unless required for flow (e.g. conditional branches).
      ```csharp
      // Avoid: opaque argument order; harder to review
      var request = new CreateOrderRequest(customerId, orderLines, optionalNotes);

      // Avoid: noisy post-construction assignments
      var request = new CreateOrderRequest();
      request.CustomerId = customerId;
      request.Lines = orderLines;
      request.Notes = optionalNotes;
      ```
  - **When records / primary constructors fit:** positional `record` or primary-constructor types stay idiomatic with `new Foo(a, b)`; object initializers apply when you are configuring a mutable/options/DTO type with many members. Required invariants that must run in a constructor are an exception,use the constructor (or factory) and then initializer only for optional surface if the API allows.

Collection expressions:
  - Prefer **[collection expressions](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/collection-expressions)** (`[e1, e2, …]`, empty **`[]`**, spread **`..sequence`**) wherever the target type supports them (`T[]`, `Span<T>`, `ReadOnlySpan<T>`, `List<T>`, `IEnumerable<T>`, `IReadOnlyList<T>`, etc.). The compiler applies efficient lowering,for example an empty **`[]`** can become **`Array.Empty<T>()`** when the value is not mutated after initialization,so **do not call `Array.Empty<T>()` by hand**; write **`[]`** and rely on the compiler. Official reference: [Collection expressions (collection literals) – C# | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/collection-expressions).
  - Use **`..`** to inline another sequence into a collection expression. For ambiguous overloads, use an explicit target type or cast (see Learn docs on conversions).
  - **Prefer `[…]` / `[]` over `new[] { … }` and `new T[] { … }`** (including empty `new T[] { }`): same semantics, collection expression is the default style when the target supports it.
  - **Not a substitute everywhere:** collection expressions are not valid where a **compile-time constant** is required; they do not apply to **inline arrays**; converting to **`IEnumerable<T>`** materializes a collection (not lazy like some LINQ). Respect those limits from the documentation.
      ```csharp
      // Good: empty, literals, spread – let the compiler optimize
      byte[] emptyBytes = [];
      ReadOnlySpan<int> window = [1, 2, 3];
      string[] combined = [..left, middle, ..right];
      int sum = Sum([1, 2, 3, 4, 5]);
      IReadOnlyList<OrderLine> noLines = [];
      int[] small = [1, 2, 3]; // not new[] { 1, 2, 3 }
      ```
      ```csharp
      // Avoid: explicit Array.Empty – use [] and target type (compiler may use Array.Empty under the hood)
      private static ReadOnlySpan<byte> LegacyBytes() => Array.Empty<byte>();
      private static readonly int[] LegacyNone = Array.Empty<int>();
      private static int[] LegacyNew() => new[] { 1, 2, 3 }; // prefer [1, 2, 3] with int[] target
      ```

Functional Patterns:
  - Use pattern matching effectively:
      ```csharp
      // Good: Clear pattern matching
      public decimal CalculateDiscount(Customer customer) =>
          customer switch
          {
              { Tier: CustomerTier.Premium } => 0.2m,
              { OrderCount: > 10 } => 0.1m,
              _ => 0m
          };
      
      // Avoid: Nested if statements
      public decimal CalculateDiscount(Customer customer)
      {
          if (customer.Tier == CustomerTier.Premium)
              return 0.2m;
          if (customer.OrderCount > 10)
              return 0.1m;
          return 0m;
      }
      ```
  - **No duplicated switch arms:** If several patterns should run the same logic, do not copy-paste the same arm body. Combine patterns (`or` in switch expressions, `case A: case B:` fall-through in switch statements) or extract shared logic into a local function or helper. Duplicated arms diverge when one copy is updated and the other is not.
      ```csharp
      // Good: single arm for equivalent cases (switch expression)
      public static string Describe(OrderStatus s) => s switch
      {
          OrderStatus.Pending or OrderStatus.Processing => "In progress",
          OrderStatus.Shipped or OrderStatus.Delivered => "Done",
          _ => "Other"
      };

      // Good: classic switch – shared body via fall-through
      switch (code)
      {
          case 200:
          case 204:
              return Result.Ok();
          default:
              return Result.Fail();
      }
      ```
      ```csharp
      // Avoid: same outcome repeated in multiple arms
      public static string Describe(OrderStatus s) => s switch
      {
          OrderStatus.Pending => "In progress",
          OrderStatus.Processing => "In progress", // duplicate – use or pattern
          OrderStatus.Shipped => "Done",
          OrderStatus.Delivered => "Done",       // duplicate
          _ => "Other"
      };
      ```
  - **Logical patterns (`or` / `and`):** When the analyzer or IDE suggests **“Merge into logical pattern”**, prefer one combined pattern instead of several separate `is` checks, redundant `if` branches, or duplicate `case` bodies that mean the same thing. Use **`or`** to merge alternatives (types, constants, `null`, relational patterns); use **`and`** when multiple conditions must hold together. Very long `or` chains may stay as a helper or `static readonly` hash set if readability suffers,otherwise merge.
      ```csharp
      // Good: single logical pattern – one place to read and change
      if (httpCode is 200 or 204 or 304)
          return Result.Cached();
      if (n is int or long or float)
          return FormatNumber(n);
      if (text is null or "")
          return "(none)";
      if (o is not null and Customer { Tier: CustomerTier.Premium })
          return ApplyPremium(o);

      // Good: property + constant via logical pattern
      if (s is { Length: 0 } or null)
          return [];
      ```
      ```csharp
      // Avoid: split checks that should be one pattern (often flagged: merge into logical pattern)
      if (httpCode is 200)
          return Result.Cached();
      if (httpCode is 204)
          return Result.Cached();

      if (n is int)
          return FormatNumber(n);
      if (n is long)
          return FormatNumber(n);
      ```
  - Prefer pure methods:
      ```csharp
      // Good: Pure function
      public static decimal CalculateTotalPrice(
          IEnumerable<OrderLine> lines,
          decimal taxRate) =>
          lines.Sum(line => line.Price * line.Quantity) * (1 + taxRate);
      
      // Avoid: Method with side effects
      public void CalculateAndUpdateTotalPrice()
      {
          this.Total = this.Lines.Sum(l => l.Price * l.Quantity);
          this.UpdateDatabase();
      }
      ```

LINQ Usage:
  - Prefer LINQ extension methods over `foreach` loops wherever the operation can be expressed declaratively (filtering, projecting, aggregating, grouping). Reach for `foreach` only when the loop has side effects, cannot be cleanly expressed as a pipeline, or measurements show that LINQ is unsuitable for a hot path:
      ```csharp
      // Good: declarative LINQ pipeline
      var completedTotal = orders
          .Where(o => o.Status == OrderStatus.Completed)
          .Select(o => o.Total)
          .Sum();
      
      // Avoid: imperative loop for a pure filter/aggregate
      decimal completedTotal = 0;
      foreach (var order in orders)
      {
          if (order.Status == OrderStatus.Completed)
              completedTotal += order.Total;
      }
      ```
  - Do not use LINQ query syntax (`from … in … select …`); always use the method/extension form. The method form composes more cleanly with non-LINQ extensions, keeps a single style across the codebase, and avoids two parallel ways of expressing the same thing:
      ```csharp
      // Good: method/extension syntax
      var activeNames = customers
          .Where(c => c.IsActive)
          .OrderBy(c => c.Name)
          .Select(c => c.Name);
      
      // Avoid: query syntax
      var activeNames = from c in customers
                        where c.IsActive
                        orderby c.Name
                        select c.Name;
      ```

Usings:
  - Do not use SDK implicit usings; keep `<ImplicitUsings>disable</ImplicitUsings>` in the project. Use a `GlobalUsings.cs` file for project-wide namespaces:
      ```csharp
      // Good: Explicit global usings in GlobalUsings.cs – visible and reviewable
      global using System;
      global using System.Collections.Generic;
      global using System.Threading;
      global using System.Threading.Tasks;
      ```
  - In source files, prefer explicit `using` at the top for file-local namespaces; rely on GlobalUsings.cs only for truly shared namespaces (e.g. System, System.Collections.Generic).

Code Organization:
  - Separate state from behavior:
      ```csharp
      // Good: Behavior separate from state
      public sealed record Order(OrderId Id, List<OrderLine> Lines);
      
      public static class OrderOperations
      {
          public static decimal CalculateTotal(Order order) =>
              order.Lines.Sum(line => line.Price * line.Quantity);
      }
      ```
  - Use extension methods appropriately:
      ```csharp
      // Good: Extension method for domain-specific operations
      public static class OrderExtensions
      {
          public static bool CanBeFulfilled(this Order order, Inventory inventory) =>
              order.Lines.All(line => inventory.HasStock(line.ProductId, line.Quantity));
      }
      ```
  - **Extensions suffix:** Only name a class with the **`Extensions`** suffix (e.g. `OrderExtensions`) if it contains **only** static methods that are extension methods for that type (the type in the first `this` parameter). Do not use `Extensions` for static helper classes that mix extension methods with other static utility methods; use a different name (e.g. `OrderHelpers`, `StringUtilities`) for those. An accepted exception is the static class named **`DependencyInjection`** (e.g. holding `Add*` extension methods for `IServiceCollection`); that name is a well-established, unique convention.
  - Prefer composition over inheritance:
      ```csharp
      // Good: Composition (preferred)
      public interface IPriceCalculator
      {
          decimal Calculate(Order order);
      }

      public sealed class OrderService
      {
          private readonly IPriceCalculator _priceCalculator;
          public OrderService(IPriceCalculator priceCalculator) => _priceCalculator = priceCalculator;
      }

      // Avoid: Inheritance for behavior reuse
      public abstract class BaseOrderService
      {
          protected abstract decimal Calculate(Order order);
      }
      ```

Dependency Management:
  - Minimize constructor injection:
      ```csharp
      // Good: Minimal dependencies
      public sealed class OrderProcessor
      {
          private readonly IOrderRepository _repository;
          
          public OrderProcessor(IOrderRepository repository)
          {
              _repository = repository;
          }
      }
      
      // Avoid: Too many dependencies
      public class OrderProcessor
      {
          public OrderProcessor(
              IOrderRepository repository,
              ILogger logger,
              IEmailService emailService,
              IMetrics metrics,
              IValidator validator)
          {
              // Too many dependencies indicates possible design issues
          }
      }
      ```
  - Prefer composition with interfaces:
      ```csharp
      // Good: Composition with interfaces
      public sealed class EnhancedLogger : ILogger
      {
          private readonly ILogger _baseLogger;
          private readonly IMetrics _metrics;
          
          public EnhancedLogger(ILogger baseLogger, IMetrics metrics)
          {
              _baseLogger = baseLogger;
              _metrics = metrics;
          }
      }
      ```

Code Clarity:
    - Prefer range indexers over LINQ:
      ```csharp
      // Good: Using range indexers with clear comments
      var lastItem = items[^1];  // ^1 means "1 from the end"
      var firstThree = items[..3];  // ..3 means "take first 3 items"
      var slice = items[2..5];  // take items from index 2 to 4 (5 exclusive)
      
      // Avoid: Using LINQ when range indexers are clearer
      var lastItem = items.LastOrDefault();
      var firstThree = items.Take(3).ToList();
      var slice = items.Skip(2).Take(3).ToList();
      ```
  - Use meaningful names:
      ```csharp
      // Good: Clear intent
      public async Task<Result<Order>> ProcessOrderAsync(
          OrderRequest request,
          CancellationToken cancellationToken)
      
      // Avoid: Unclear abbreviations
      public async Task<Result<T>> ProcAsync<T>(ReqDto r, CancellationToken ct)
      ```

XML Documentation Style:
  - Always write block-shaped XML doc tags (`<summary>`, `<remarks>`, `<example>`, etc.) as **multi-line blocks**: opening tag, content, and closing tag each on their own `///` line, even when the content is a single short sentence. Inline parameter-level tags (`<param>`, `<returns>`, `<typeparam>`, `<exception>`) stay on a single `///` line. See `documentation-style.md` for the brevity limits applied to the content.
      ```csharp
      // Good: multi-line summary block, single-sentence content; inline <param>/<returns>
      /// <summary>
      /// Order identifier.
      /// </summary>
      public OrderId Id { get; init; }

      /// <summary>
      /// Order line items.
      /// </summary>
      public ImmutableList<OrderLine> Lines { get; init; }

      /// <summary>
      /// Calculates the total price including tax for the given order.
      /// </summary>
      /// <param name="order">The order to calculate the total for.</param>
      /// <param name="taxRate">The tax rate to apply.</param>
      /// <returns>The total price including tax.</returns>
      public decimal CalculateTotal(Order order, decimal taxRate) { /* ... */ }
      ```
      ```csharp
      // Avoid: tags and content collapsed onto a single line, breaks the consistent block shape.
      /// <summary>Order identifier.</summary>
      public OrderId Id { get; init; }

      /// <summary>Calculates total price.</summary>
      public decimal CalculateTotal(Order order, decimal taxRate) { /* ... */ }
      ```

Error Handling:
  - Use Result types for expected failures:
      ```csharp
      // Good: Explicit error handling
      public sealed record Result<T>
      {
          public T? Value { get; }
          public Error? Error { get; }
          
          private Result(T value) => Value = value;
          private Result(Error error) => Error = error;
          
          public static Result<T> Success(T value) => new(value);
          public static Result<T> Failure(Error error) => new(error);
      }
      ```
  - Prefer exceptions for exceptional cases:
      ```csharp
      // Good: Exception for truly exceptional case
      public static OrderId From(string value)
      {
          if (!Guid.TryParse(value, out var guid))
              throw new ArgumentException("Invalid OrderId format", nameof(value));
          
          return new OrderId(guid);
      }
      ```

Testing Considerations:
  - Design for testability:
      ```csharp
      // Good: Easy to test pure functions
      public static class PriceCalculator
      {
          public static decimal CalculateDiscount(
              decimal price,
              int quantity,
              CustomerTier tier) =>
              // Pure calculation
      }
      
      // Avoid: Hard to test due to hidden dependencies
      public decimal CalculateDiscount()
      {
          var user = _userService.GetCurrentUser();  // Hidden dependency
          var settings = _configService.GetSettings(); // Hidden dependency
          // Calculation
      }
      ```

Immutable Collections:
  - Use System.Collections.Immutable with records:
      ```csharp
      // Good: Immutable collections in records
      public sealed record Order(
          OrderId Id, 
          ImmutableList<OrderLine> Lines,
          ImmutableDictionary<string, string> Metadata);
      
      // Avoid: Mutable collections in records
      public record Order(
          OrderId Id,
          List<OrderLine> Lines,  // Can be modified after creation
          Dictionary<string, string> Metadata);
      ```
  - Initialize immutable collections efficiently:
      ```csharp
      // Good: Using builder pattern
      var builder = ImmutableList.CreateBuilder<OrderLine>();
      foreach (var line in lines)
      {
          builder.Add(line);
      }
      return new Order(id, builder.ToImmutable());
      
      // Also Good: Using collection initializer
      return new Order(
          id,
          lines.ToImmutableList(),
          metadata.ToImmutableDictionary());
      ```

// ... existing code ...

Error Handling:
  - Use Result types for expected failures:
      ```csharp
      // Good: Explicit error handling
      public sealed record Result<T>
      {
          public T? Value { get; }
          public Error? Error { get; }
          
          private Result(T value) => Value = value;
          private Result(Error error) => Error = error;
          
          public static Result<T> Success(T value) => new(value);
          public static Result<T> Failure(Error error) => new(error);
      }
      ```
  - Prefer exceptions for exceptional cases:
      ```csharp
      // Good: Exception for truly exceptional case
      public static OrderId From(string value)
      {
          if (!Guid.TryParse(value, out var guid))
              throw new ArgumentException("Invalid OrderId format", nameof(value));
          
          return new OrderId(guid);
      }
      ```

Safe Operations:
  - Use Try methods for safer operations:
      ```csharp
      // Good: Using TryGetValue for dictionary access
      if (dictionary.TryGetValue(key, out var value))
      {
          // Use value safely here
      }
      else
      {
          // Handle missing key case
      }

      // Avoid: Direct indexing which can throw
      var value = dictionary[key];  // Throws if key doesn't exist

      // Good: Using Uri.TryCreate for URL parsing
      if (Uri.TryCreate(urlString, UriKind.Absolute, out var uri))
      {
          // Use uri safely here
      }
      else
      {
          // Handle invalid URL case
      }

      // Avoid: Direct Uri creation which can throw
      var uri = new Uri(urlString);  // Throws on invalid URL

      // Good: Using int.TryParse for number parsing
      if (int.TryParse(input, out var number))
      {
          // Use number safely here
      }
      else
      {
          // Handle invalid number case
      }

      // Good: Combining Try methods with null coalescing
      var value = dictionary.TryGetValue(key, out var result)
          ? result
          : defaultValue;

      // Good: Using Try methods in LINQ with pattern matching
      var validNumbers = strings
          .Select(s => (Success: int.TryParse(s, out var num), Value: num))
          .Where(x => x.Success)
          .Select(x => x.Value);
      ```
      
  - Prefer Try methods over exception handling:
      ```csharp
      // Good: Using Try method
      if (decimal.TryParse(priceString, out var price))
      {
          // Process price
      }

      // Avoid: Exception handling for expected cases
      try
      {
          var price = decimal.Parse(priceString);
          // Process price
      }
      catch (FormatException)
      {
          // Handle invalid format
      }
      ```

Asynchronous Programming:
  - Avoid async void:
      ```csharp
      // Good: Async method returns Task
      public async Task ProcessOrderAsync(Order order)
      {
          await _repository.SaveAsync(order);
      }
      
      // Avoid: Async void can crash your application
      public async void ProcessOrder(Order order)
      {
          await _repository.SaveAsync(order);
      }
      ```
  - Use Task.FromResult for pre-computed values:
      ```csharp
      // Good: Return pre-computed value
      public Task<int> GetDefaultQuantityAsync() =>
          Task.FromResult(1);
      
      // Better: Use ValueTask for zero allocations
      public ValueTask<int> GetDefaultQuantityAsync() =>
          new ValueTask<int>(1);
      
      // Avoid: Unnecessary thread pool usage
      public Task<int> GetDefaultQuantityAsync() =>
          Task.Run(() => 1);
      ```
  - Always flow CancellationToken:
      ```csharp
      // Good: Propagate cancellation
      public async Task<Order> ProcessOrderAsync(
          OrderRequest request,
          CancellationToken cancellationToken)
      {
          var order = await _repository.GetAsync(
              request.OrderId, 
              cancellationToken);
              
          await _processor.ProcessAsync(
              order, 
              cancellationToken);
              
          return order;
      }
      ```
  - Prefer await over ContinueWith:
      ```csharp
      // Good: Using await
      public async Task<Order> ProcessOrderAsync(OrderId id)
      {
          var order = await _repository.GetAsync(id);
          await _validator.ValidateAsync(order);
          return order;
      }
      
      // Avoid: Using ContinueWith
      public Task<Order> ProcessOrderAsync(OrderId id)
      {
          return _repository.GetAsync(id)
              .ContinueWith(t => 
              {
                  var order = t.Result; // Can deadlock
                  return _validator.ValidateAsync(order);
              });
      }
      ```
  - Never use Task.Result or Task.Wait:
      ```csharp
      // Good: Async all the way
      public async Task<Order> GetOrderAsync(OrderId id)
      {
          return await _repository.GetAsync(id);
      }
      
      // Avoid: Blocking on async code
      public Order GetOrder(OrderId id)
      {
          return _repository.GetAsync(id).Result; // Can deadlock
      }
      ```
  - Use TaskCompletionSource correctly:
      ```csharp
      // Good: Using RunContinuationsAsynchronously
      private readonly TaskCompletionSource<Order> _tcs = 
          new(TaskCreationOptions.RunContinuationsAsynchronously);
      
      // Avoid: Default TaskCompletionSource can cause deadlocks
      private readonly TaskCompletionSource<Order> _tcs = new();
      ```
  - Always dispose CancellationTokenSources:
      ```csharp
      // Good: Proper disposal of CancellationTokenSource
      public async Task<Order> GetOrderWithTimeout(OrderId id)
      {
          using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
          return await _repository.GetAsync(id, cts.Token);
      }
      ```
  - Prefer async/await over direct Task return:
      ```csharp
      // Good: Using async/await
      public async Task<Order> ProcessOrderAsync(OrderRequest request)
      {
          await _validator.ValidateAsync(request);
          var order = await _factory.CreateAsync(request);
          return order;
      }
      
      // Avoid: Manual task composition
      public Task<Order> ProcessOrderAsync(OrderRequest request)
      {
          return _validator.ValidateAsync(request)
              .ContinueWith(t => _factory.CreateAsync(request))
              .Unwrap();
      }
      ```

Nullability:
  - Enable nullable reference types:
      ```xml
      <PropertyGroup>
        <Nullable>enable</Nullable>
        <WarningsAsErrors>nullable</WarningsAsErrors>
      </PropertyGroup>
      ```
  - Mark nullable fields explicitly:
      ```csharp
      // Good: Explicit nullability
      public class OrderProcessor
      {
          private readonly ILogger<OrderProcessor>? _logger;
          private string? _lastError;
          
          public OrderProcessor(ILogger<OrderProcessor>? logger = null)
          {
              _logger = logger;
          }
      }
      
      // Avoid: Implicit nullability
      public class OrderProcessor
      {
          private readonly ILogger<OrderProcessor> _logger; // Warning: Could be null
          private string _lastError; // Warning: Could be null
      }
      ```
  - Use null checks appropriately:
      ```csharp
      // Good: Proper null checking
      public void ProcessOrder(Order? order)
      {
          if (order is null)
              throw new ArgumentNullException(nameof(order));
              
          _logger?.LogInformation("Processing order {Id}", order.Id);
      }
      
      // Good: Using pattern matching for null checks
      public decimal CalculateTotal(Order? order) =>
          order switch
          {
              null => throw new ArgumentNullException(nameof(order)),
              { Lines: null } => throw new ArgumentException("Order lines cannot be null", nameof(order)),
              _ => order.Lines.Sum(l => l.Total)
          };
      ```
  - Use null-forgiving operator when appropriate:
      ```csharp
      public class OrderValidator
      {
          private readonly IValidator<Order> _validator;
          
          public OrderValidator(IValidator<Order> validator)
          {
              _validator = validator ?? throw new ArgumentNullException(nameof(validator));
          }
          
          public ValidationResult Validate(Order order)
          {
              // We know _validator can't be null due to constructor check
              return _validator!.Validate(order);
          }
      }
      ```
  - Use nullability attributes:
      ```csharp
      public class StringUtilities
      {
          // Output is non-null if input is non-null
          [return: NotNullIfNotNull(nameof(input))]
          public static string? ToUpperCase(string? input) =>
              input?.ToUpperInvariant();
          
          // Method never returns null
          [return: NotNull]
          public static string EnsureNotNull(string? input) =>
              input ?? string.Empty;
          
          // Parameter must not be null when method returns true
          public static bool TryParse(string? input, [NotNullWhen(true)] out string? result)
          {
              result = null;
              if (string.IsNullOrEmpty(input))
                  return false;
                  
              result = input;
              return true;
          }
      }
      ```
  - Use init-only properties with non-null validation:
      ```csharp
      // Good: Non-null validation in constructor
      public sealed record Order
      {
          public required OrderId Id { get; init; }
          public required ImmutableList<OrderLine> Lines { get; init; }
          
          public Order()
          {
              Id = null!; // Will be set by required property
              Lines = null!; // Will be set by required property
          }
          
          private Order(OrderId id, ImmutableList<OrderLine> lines)
          {
              Id = id;
              Lines = lines;
          }
          
          public static Order Create(OrderId id, IEnumerable<OrderLine> lines) =>
              new(id, lines.ToImmutableList());
      }
      ```
  - Document nullability in interfaces:
      ```csharp
      public interface IOrderRepository
      {
          // Explicitly shows that null is a valid return value
          Task<Order?> FindByIdAsync(OrderId id, CancellationToken ct = default);
          
          // Method will never return null
          [return: NotNull]
          Task<IReadOnlyList<Order>> GetAllAsync(CancellationToken ct = default);
          
          // Parameter cannot be null
          Task SaveAsync([NotNull] Order order, CancellationToken ct = default);
      }
      ```

Symbol References:
  - Always use nameof operator:
      ```csharp
      // Good: Using nameof for parameter names
      public void ProcessOrder(Order order)
      {
          if (order is null)
              throw new ArgumentNullException(nameof(order));
      }
      
      // Good: Using nameof for property names
      public class Customer
      {
          private string _email;
          
          public string Email
          {
              get => _email;
              set => _email = value ?? throw new ArgumentNullException(nameof(value));
          }
          
          public void UpdateEmail(string newEmail)
          {
              if (string.IsNullOrEmpty(newEmail))
                  throw new ArgumentException("Email cannot be empty", nameof(newEmail));
              
              Email = newEmail;
          }
      }
      
      // Good: Using nameof in attributes
      public class OrderProcessor
      {
          [Required(ErrorMessage = "The {0} field is required")]
          [Display(Name = nameof(OrderId))]
          public string OrderId { get; init; }
          
          [MemberNotNull(nameof(_repository))]
          private void InitializeRepository()
          {
              _repository = new OrderRepository();
          }
          
          [NotifyPropertyChangedFor(nameof(FullName))]
          public string FirstName
          {
              get => _firstName;
              set => SetProperty(ref _firstName, value);
          }
      }
      
      // Avoid: Hard-coded string references
      public void ProcessOrder(Order order)
      {
          if (order is null)
              throw new ArgumentNullException("order"); // Breaks refactoring
      }
      ```
  - Use nameof with exceptions:
      ```csharp
      public class OrderService
      {
          public async Task<Order> GetOrderAsync(OrderId id, CancellationToken ct)
          {
              var order = await _repository.FindAsync(id, ct);
              
              if (order is null)
                  throw new OrderNotFoundException(
                      $"Order with {nameof(id)} '{id}' not found");
                      
              if (!order.Lines.Any())
                  throw new InvalidOperationException(
                      $"{nameof(order.Lines)} cannot be empty");
                      
              return order;
          }
          
          public void ValidateOrder(Order order)
          {
              ArgumentNullException.ThrowIfNull(order, nameof(order));
              
              if (order.Lines.Count == 0)
                  throw new ArgumentException(
                      "Order must have at least one line",
                      nameof(order));
          }
      }
      ```
  - Use nameof in logging:
      ```csharp
      public class OrderProcessor
      {
          private readonly ILogger<OrderProcessor> _logger;
          
          public async Task ProcessAsync(Order order)
          {
              _logger.LogInformation(
                  "Starting {Method} for order {OrderId}",
                  nameof(ProcessAsync),
                  order.Id);
                  
              try
              {
                  await ProcessInternalAsync(order);
              }
              catch (Exception ex)
              {
                  _logger.LogError(
                      ex,
                      "Error in {Method} for {Property} {Value}",
                      nameof(ProcessAsync),
                      nameof(order.Id),
                      order.Id);
                  throw;
              }
          }
      }
      ```

# End of Claude Rules File 