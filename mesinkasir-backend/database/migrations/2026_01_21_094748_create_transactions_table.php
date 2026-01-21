<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
  public function up(): void
  {
    Schema::create('transactions', function (Blueprint $table) {
      $table->id();

      $table->foreignId('cashier_id')
        ->constrained('users')
        ->cascadeOnUpdate()
        ->restrictOnDelete();

      $table->json('items');
      $table->unsignedBigInteger('total_amount');
      $table->unsignedBigInteger('paid_amount');
      $table->unsignedBigInteger('change_amount');
      $table->timestamp('paid_at');
      $table->timestamps();
      $table->index(['cashier_id', 'paid_at']);
    });
  }

  public function down(): void
  {
    Schema::dropIfExists('transactions');
  }
};
