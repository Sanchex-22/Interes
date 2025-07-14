import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalculatorScreen extends StatefulWidget {
  @override
  _CalculatorScreenState createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final formatter = NumberFormat.currency(symbol: '\$');
  double _capital = 0.0;
  double _rate = 0.0;
  int _rounds = 0;
  double _result = 0.0;

  void _calculate() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      double total = _capital;
      for (int i = 0; i < _rounds; i++) {
        total *= (1 + (_rate / 100));
      }
      setState(() {
        _result = total;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calculadora Interés Compuesto')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Capital inicial'),
                keyboardType: TextInputType.number,
                onSaved: (value) => _capital = double.parse(value!),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Porcentaje por vuelta (%)'),
                keyboardType: TextInputType.number,
                onSaved: (value) => _rate = double.parse(value!),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Cantidad de vueltas'),
                keyboardType: TextInputType.number,
                onSaved: (value) => _rounds = int.parse(value!),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _calculate, child: Text('Calcular')),
              SizedBox(height: 20),
              Text('Resultado: ${formatter.format(_result)}', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
