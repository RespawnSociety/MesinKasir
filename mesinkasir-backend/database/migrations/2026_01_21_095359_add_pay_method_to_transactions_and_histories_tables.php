<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
  public function up(): void
  {
    Schema::table('transactions', function (Blueprint $table) {
      $table->unsignedTinyInteger('pay_method')
        ->default(1)
        ->after('items'); // atau after('cashier_id') kalau kamu mau
    });

    Schema::table('transaction_histories', function (Blueprint $table) {
      $table->unsignedTinyInteger('pay_method')
        ->default(1)
        ->after('items');
    });
  }

  public function down(): void
  {
    Schema::table('transactions', function (Blueprint $table) {
      $table->dropColumn('pay_method');
    });

    Schema::table('transaction_histories', function (Blueprint $table) {
      $table->dropColumn('pay_method');
    });
  }
};
