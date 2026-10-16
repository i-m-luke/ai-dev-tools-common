namespace Shop.Controllers;

public class InvoicesController(InvoiceService invoices)
{
    public Invoice IssueInvoice(string customerEmail, decimal amount) => invoices.Issue(customerEmail, amount);

    public void MarkPaid(int invoiceId) => invoices.MarkPaid(invoiceId);
}
