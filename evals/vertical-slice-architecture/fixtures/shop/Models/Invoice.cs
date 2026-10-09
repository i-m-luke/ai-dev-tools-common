namespace Shop.Models;

public record Invoice(int Id, string CustomerEmail, decimal Amount, bool Paid);
