import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_sphere_ai/providers/auth_provider.dart';

class AdminCreateUserScreen extends ConsumerStatefulWidget {
  const AdminCreateUserScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminCreateUserScreen> createState() => _AdminCreateUserScreenState();
}

class _AdminCreateUserScreenState extends ConsumerState<AdminCreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _employee = {};
  final Map<String, dynamic> _user = {};
  bool _createUser = false;
  bool _loading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _loading = true);
    try {
      final auth = ref.read(authProvider.notifier);
      final result = await auth.createEmployee(employee: _employee, user: _createUser ? _user : null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Created: ${result["id"]}')));
      _formKey.currentState!.reset();
      setState(() {
        _createUser = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Employee')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Employee ID'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => _employee['employee_id'] = v!.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => _employee['full_name'] = v!.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                keyboardType: TextInputType.emailAddress,
                onSaved: (v) => _employee['email'] = v?.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Job title (optional)'),
                onSaved: (v) => _employee['job_title'] = v?.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Salary per hour'),
                keyboardType: TextInputType.number,
                onSaved: (v) => _employee['salary_per_hour'] = double.tryParse(v ?? '0') ?? 0.0,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Create user account'),
                value: _createUser,
                onChanged: (v) => setState(() => _createUser = v),
              ),
              if (_createUser) ...[
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Account email'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onSaved: (v) => _user['email'] = v!.trim(),
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Account full name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onSaved: (v) => _user['full_name'] = v!.trim(),
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Temporary password'),
                  validator: (v) => v == null || v.length < 8 ? 'Min 8 chars' : null,
                  obscureText: true,
                  onSaved: (v) => _user['password'] = v!.trim(),
                ),
                DropdownButtonFormField<String>(
                  value: 'employee',
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'hr', child: Text('HR')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => _user['role'] = v,
                  onSaved: (v) => _user['role'] = v,
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading ? const CircularProgressIndicator() : const Text('Create'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
