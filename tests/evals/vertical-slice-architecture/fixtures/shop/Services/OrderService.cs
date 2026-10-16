namespace Shop.Services;

public class OrderService(EmailSender email)
{
    private readonly List<Order> _orders = [];

    public IReadOnlyList<Order> Recent(int count) => _orders.TakeLast(count).ToList();

    public void Place(Order order)
    {
        _orders.Add(order);
        email.Send(order.CustomerEmail, $"Order {order.Id} received");
    }

    public void Cancel(int orderId) => _orders.RemoveAll(o => o.Id == orderId);
}
