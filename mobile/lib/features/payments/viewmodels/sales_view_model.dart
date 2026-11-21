import '../../../core/viewmodel/paged_list_view_model.dart';
import '../../../data/models/paged.dart';
import '../../../data/models/payment_models.dart';
import '../../../data/remote/payment_service.dart';

/// Aba "Vendas" (prestador/admin) ou "Pagamentos" (cliente): lista + resumo.
class SalesViewModel extends PagedListViewModel<Charge> {
  SalesViewModel(this._service);

  final PaymentService _service;
  SalesSummary _summary = SalesSummary.empty;

  SalesSummary get summary => _summary;

  @override
  Future<Paged<Charge>> fetchPage(int offset) async {
    final r = await _service.list(offset: offset);
    _summary = r.summary;
    return r.page;
  }
}
