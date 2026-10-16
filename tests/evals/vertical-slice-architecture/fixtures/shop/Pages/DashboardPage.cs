namespace Shop.Pages;

// Start page: recent orders next to unpaid invoices.
public class DashboardPage(OrderService orders, InvoiceService invoices)
{
    public void Render()
    {
        foreach (var order in orders.Recent(5)) Console.WriteLine($"Order {order.Id}");
        foreach (var invoice in invoices.Unpaid()) Console.WriteLine($"Unpaid invoice {invoice.Id}");
    }
}
