namespace Shop.Services;

public class InvoiceService(EmailSender email)
{
    private readonly List<Invoice> _invoices = [];

    public IReadOnlyList<Invoice> Unpaid() => _invoices.Where(i => !i.Paid).ToList();

    public Invoice Issue(string customerEmail, decimal amount)
    {
        var invoice = new Invoice(_invoices.Count + 1, customerEmail, amount, Paid: false);
        _invoices.Add(invoice);
        email.Send(customerEmail, $"Invoice {invoice.Id}: {amount:C}");
        return invoice;
    }

    public void MarkPaid(int invoiceId)
    {
        var index = _invoices.FindIndex(i => i.Id == invoiceId);
        _invoices[index] = _invoices[index] with { Paid = true };
    }
}
