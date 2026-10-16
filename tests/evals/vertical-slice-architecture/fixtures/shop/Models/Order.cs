namespace Shop.Models;

public record Order(int Id, string CustomerEmail, IReadOnlyList<string> Items);
