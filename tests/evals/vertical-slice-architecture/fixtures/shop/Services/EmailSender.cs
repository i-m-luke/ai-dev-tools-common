namespace Shop.Services;

public class EmailSender
{
    public void Send(string to, string message) => Console.WriteLine($"To {to}: {message}");
}
