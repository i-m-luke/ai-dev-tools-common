namespace Shop.Controllers;

public class OrdersController(OrderService orders)
{
    public void PlaceOrder(Order order) => orders.Place(order);

    public void CancelOrder(int orderId) => orders.Cancel(orderId);
}
